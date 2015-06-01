# snuffbox
Designed for controlling the temperature of a snuff production with humidity and temperature sensor

## Design criterias
1. Cold is better than fire. I.e. if something goes wrong/app crashes, don't leave the heat on
2. Webpage to view it
3. Don't toggle the heat too often to keep the relay from wearing out

## Hardware used/recommended

* Use any relay that can be controlled with a _very_ low Ampere 3.3V  voltage.
  I use a relay board with a transistor amplifying the signal.
  ( http://www.lawicel-shop.se/prod/Relay-Kit-1_873852/LAWICEL-AB_8758/ENG/SEK )
  The diode on the relay board is _very_ nice when trying to debug it.
* I use AM2302 as the sensor, because it was the only affordable humidity and temperature sensor available.
  http://www.adafruit.com/products/393

## Installation

```
sudo apt-get install couchdb python-couchdb python-pip
pip install couchapp

git clone https://github.com/tobias-/snuffbox/

cd snuffbox/couchdb/
couchapp push . http://localhost:5984/env_logg

cd ..
sudo cp logger.py Adafruit_DHT /usr/local/bin/

echo 'logg:23:respawn:/usr/local/bin/logger.py' | sudo tee /etc/inittab
```
