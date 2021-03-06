#!/usr/bin/env python

import couchdb
from sys import argv
import RPi.GPIO as GPIO
from subprocess import Popen, PIPE
from re import search, M
from time import time, strftime, gmtime, sleep
import signal

class Snuffbox:
    def updateConfig(self):
        if not self.__monitorName in self.__configdb:
            self.__config["_id"] = self.__monitorName
            self.__configdb.save(self.__config)
        else:
            cfg = self.__configdb[self.__monitorName]
            if self.validateConfig(cfg):
                if self.__config["heater_pin"] != cfg["heater_pin"]:
                    self.setHeater(False)
                    GPIO.setup(self.config["heater_pin"], GPIO.IN)
                    self.__heater = False
                self.__config = cfg
                return True
            else:
                return False
        return True

    def validateConfig(self, cfg=None):
        if not cfg:
            cfg = self.__config
        ok = 1;
        ok &= str(cfg["target_temperature"]).isdigit()
        ok &= str(cfg["min_relay_settle"]).isdigit()
        ok &= str(cfg["min_log_delay"]).isdigit()
        ok &= str(cfg["sensor_pin"]).isdigit()
        ok &= str(cfg["heater_pin"]).isdigit()
        return ok

    def __init__(self, name, baseUrl="http://localhost:5984/", db="env_logg", configdb="env_logg", readTemp="/usr/local/bin/Adafruit_DHT"):
        self.name = name
        self.baseUrl = baseUrl
        self.db = db
        self.configdb = configdb
        self.__readTemp = readTemp
        self.__monitorName = name
        self.__heater = 0
        self.__heaterLastChanged = 0
        self.__logLast = 0
        self.setup()

    def setup(self):
        couch = couchdb.Server(self.baseUrl)
        
        if self.db in couch:
            self.__couchdb = couch[self.db]
        else:
            self.__couchdb = couch.create(self.db)

        if self.configdb in couch:
            self.__configdb = couch[self.configdb]
        else:
            self.__configdb = couch.create(self.configdb)
        
        self.__config = {
            "target_temperature": 70,
            "min_relay_settle": 20,
            "min_log_delay": 60,
            "sensor_pin": 4,
            "heater_pin": 17,
        }


    def setHeater(self, putHeaterOn):
        GPIO.setmode(GPIO.BCM)
        GPIO.setup(self.__config["heater_pin"], GPIO.OUT)
        GPIO.output(self.__config["heater_pin"], putHeaterOn)
        print(strftime("%Y-%m-%d %H:%M:%S: turning heater " + str(putHeaterOn), gmtime()))


    def loadTempAndHumidity(self):
        proc = Popen([self.__readTemp, "2302", str(self.__config["sensor_pin"])], stdout=PIPE, stderr=PIPE, bufsize=4096)
        n = 0;
        while proc.poll() == None and n < 10:
            sleep(0.5)
            n = n + 1
        if n == 10:
            proc.kill()
        else:
            (lines, foo) = proc.communicate(input)
            for line in lines.split('\n'):
                match = search(r'^Temp = +([\d.]+) \*C, Hum = +([\d.]+) %', line, M)
                if match:
                    result = {}
                    result["actual_temperature"] = match.group(1)
                    result["actual_humidity"] = match.group(2)
                    print("Temperature: " + match.group(1) + " Humidity: " + match.group(2))
                    return result
        return None

    def __upload(self, result, id = None):
        print(strftime("%Y-%m-%d %H:%M:%S: Logging", gmtime()))
        if id:
            try:
                doc = self.__couchdb[id]
                doc = dict(doc.items() + result.items())
            except:
                doc = result.copy()
                doc["_id"] = id
        else:
            doc = result.copy()
        doc["unix_time"] = int(time())
        doc["current_time"] = strftime("%Y-%m-%d %H:%M:%S", gmtime())
        if self.__heater:
            doc["heater_on"] = "true"
        else:
            doc["heater_on"] = "false"
        doc["sensor_pin"] = self.__config["sensor_pin"]
        doc["target_temperature"] = self.__config["target_temperature"]
        doc["config_name"] = self.__monitorName
        print(doc)
        self.__couchdb.save(doc);

    def run(self):
        self.updateConfig()
        if self.validateConfig():
            measured = self.loadTempAndHumidity()
            if measured:
                if self.__heaterLastChanged < (time() - self.__config["min_relay_settle"]):
                    wantedheat = False
                    if float(self.__config["target_temperature"]) > float(measured["actual_temperature"]):
                        wantedheat = True
                    if wantedheat != self.__heater:
                        self.setHeater(wantedheat)
                        self.__heaterLastChanged = time()
                        self.__heater = wantedheat
                if self.__logLast < (time() - self.__config["min_log_delay"]):
                    self.__upload(measured)
                    self.__logLast = time()
                self.__upload(measured, self.__monitorName+":current_temp")


    def shutdown(self, signum, stack):
        print("Shutting down")
        self.setHeater(False)


if __name__ == "__main__":
    name = "local"
    if len(argv) > 1:
        name = argv[1]
    snuffbox = Snuffbox(name)
    try:
        while True:
            snuffbox.run()
    finally:
        snuffbox.shutdown("", "")
