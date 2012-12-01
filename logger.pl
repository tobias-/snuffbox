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

my $heater = 0;
my $heaterLastChanged = 0;



my %config = (
	poll_interval => 10,
	target_temperature => 70,
	min_relay_settle => 20,
	sensor_pin => 4,
	heater_pin => 17,
);

sub setHeater() {
	open(GPIO, ">/sys/class/gpio/export") || die "Could not open GPIO";
	print GPIO ($config{heater_pin}."\n");
	close(GPIO);
	open(GPIO, ">/sys/class/gpio/gpio".$config{heater_pin}."/direction") || die "Could not open GPIO";
	print GPIO "out\n";
	close(GPIO);
	open(GPIO, ">/sys/class/gpio/gpio".$config{heater_pin}."/value") || die "Could not open GPIO";
	print GPIO "$heater\n";
	close(GPIO);
}

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
		$config{$key} = $doc{$key};
	}
}

sub isdigit($) {
	my ($key) = (@_);
	if ($config{$key} =~ /^\d+$/) {
		return 1;
	} else {
		print "$key is not a digit (".$config{$key}.")\n";
		return 0;
	}
}

sub validateConfig() {
	my $ok = 1;
	$ok &&= isdigit "poll_interval";
	$ok &&= isdigit "target_temperature";
	$ok &&= isdigit "min_relay_settle";
	$ok &&= isdigit "sensor_pin";
	$ok &&= isdigit "heater_pin";
	return $ok;
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


updateConfig();
setHeater();
my $ptime;
my $stime;
while (1) {
	updateConfig();
	if (validateConfig()) {
		my %values = getEnvValues();
		if (scalar keys %values > 1) {
			upload(%values);
			my $wantedHeat = $config{target_temperature} > $values{actual_temperature};
			if ($heaterLastChanged < (time - $config{min_relay_settle}) && $wantedHeat != $heater) {
				$heater = $wantedHeat;
				setHeater();
				$heaterLastChanged = time;
			}
		}
	} else {
		print "Config parse failed\n";
	}
	$ptime = $config{poll_interval};
	$stime = (($ptime+1) - (time % $ptime));
	sleep $stime;
}
