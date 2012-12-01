#!/usr/bin/perl -w

use strict;

use CouchDB::Client;

my $example = <<EXAMPLE;
Using pin #4
Data (40): 0x1 0x23 0x0 0xd4 0xf8
Temp =  21.2 *C, Hum = 29.1 %
EXAMPLE

my %config = (poll_interval => 10, target_temperature => 70, min_relay_settle => 20);

my $base = "http://localhost:5984/environment";

my $couch = CouchDB::Client->new(uri => 'http://localhost:5984/');
my $configDB = $couch->newDB('env_config');
if (! $configDB->validName()) {
	$configDB->create();
	my $configView = $configDB->newDesignDoc('_design/listConfig')->retrieve;
}
$configDB->dbInfo;





my $envDB = $couch->newDB('env_config');
if (! $envDB->validName()) {
	$envDB->create();
}

sub updateConfig() {
	my $res = $dd->queryView('all');
	foreach $docRef @$res {
		my %doc = %$docRef;
		print $doc{key}."=>".$config{data}->{value};
	}
}






updateConfig();

sub upload($$) {
	my ($temp, $humidity) = @_;
	my $time = time;
	my $htime = localtime($time);
	post("environment/".$time, <<JSON);
{ 
	"value": {
		"temp": "$temp",
		"humidity": "$humidity"
		"time": "$time",
		"htime": "$htime",
		"heater_on": "$heater",
	}
}
JSON
}


while (1) {
	open(HUMOR, "sudo Adafruit_DHT 2302 4|");
	if(tell(HUMOR) != -1) {
		die "Can't open Adafruit_DHT";
	}

	my $temp;
	my $humidity;

	while(<HUMOR>) {
		if (/^Temp = +([\d.]+), Hum = +([\d.]+) %/) {
			$temp = $1;
			$humidity = $2;
		}
	}
	if (defined $temp) {
		upload($temp, $humidity);
	}
	close(HUMOR);
	sleep 3;
}
