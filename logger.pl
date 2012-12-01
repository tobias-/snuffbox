#!/usr/bin/perl -w

use strict;
use TryCatch;
use Data::Dumper;
use Carp::Always;

use CouchDB::Client;

my $name = 'local';
if (scalar @ARGV > 0) {
	$name = $ARGV[0];
}

my $heater = 1;

my $example = <<EXAMPLE;
Using pin #4
Data (40): 0x1 0x23 0x0 0xd4 0xf8
Temp =  21.2 *C, Hum = 29.1 %
EXAMPLE

my %config = (
	poll_interval => 10,
	target_temperature => 70,
	min_relay_settle => 20,
	sensor_pin => 4
);

my $base = "http://localhost:5984/environment";

my $couch = CouchDB::Client->new(uri => 'http://localhost:5984/');
my $configDB = $couch->newDB('env_config');
if (! $couch->dbExists('env_config')) {
	$configDB->create();
}
my $configDoc = $configDB->newDoc($name);
if (! $configDB->docExists($name)) {
	$configDoc->data = \%config;
	$configDoc->create();
}

my $envDB = $couch->newDB('env_logg');
if (! $couch->dbExists('env_logg')) {
	$envDB->create();
}



sub updateConfig() {
	my $res = $configDoc->retrieve;
	my %doc = %{$res->data};
	my $key;
	foreach $key (keys %doc) {
		#print $key."=>".$doc{$key}."\n";
		$config{$key} = $doc{$key};
	}
}

sub validateConfig() {
	my $ok = 1;
#	my $ok &= isdigit $config{poll_interval};
#	my $ok &= isdigit $config{target_temperature};
#	my $ok &= isdigit $config{min_relay_settle};
#	my $ok &= isdigit $config{sensor_pin};
#	return $ok;
}

sub getEnvValues() {
	my %result;

	open(HUMOR, "Adafruit_DHT 2302 ".$config{sensor_pin}."|");
	if(tell(HUMOR) == -1) {
		die "Can't open Adafruit_DHT";
	}

	while(<HUMOR>) {
		if (/^Temp = +([\d.]+) \*C, Hum = +([\d.]+) %/) {
			$result{actual_temperature} = $1;
			$result{actual_humidity} = $2;
		}
	}
	close(HUMOR);
	return %result;
}


sub upload(%) {
	my %values = @_;
	my $time = time;
	$values{unix_time} = $time;
	$values{current_time} = localtime($time);
	$values{heater_on} = $heater?"true":"false";
	$values{sensor_pin} = $config{sensor_pin};
	$values{target_temperature} = $config{target_temperature};
	$values{config_name} = $name;
	my $doc = $envDB->newDoc();
	%{$doc->data} = %values;
	$doc->create();
}


my %values;
my $ptime;
while (1) {
	updateConfig();
	if (validateConfig()) {
		%values = getEnvValues();
		if (scalar keys %values > 1) {
			upload(%values);
		}
	} else {
		print "Config parse failed\n";
	}
	$ptime = $config{poll_interval};
	sleep (($ptime+1) - (time % $ptime));
}
