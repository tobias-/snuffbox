var oldHeater = "false";
var db = $.couch.db(unescape(document.location.pathname).split('/')[1]);
var sensorName = window.location.hash;
if (! sensorName) {
	sensorName = "local";
}
function updateTemp() {
	db.openDoc(sensorName+":current_temp", {
		type: 'GET',
		success : function(data, status, xhr) {
			$("#temperature").html(data['actual_temperature'] + "°C");
			$("#humidity").html(data['actual_humidity'] + "%");
			if (oldHeater === data["heater_on"]) {
			} else {
				if (data["heater_on"] === "true") {
					$("#heaterTable").css("background-image", "url('images/Fire.jpg')");
				} else {
					$("#heaterTable").css("background-image", "none");
				}
				oldHeater = data["heater_on"];
			}
			$("#dataAge").html(Math.floor((new Date().getTime() / 1000) - data['unix_time']) + " second(s) ago");
		}
	});
};
function setTemp() {
	db.openDoc(sensorName, {
		success : function(data) {
			$("#targetTemperature").val(data['target_temperature']);
		}
	});
}
$(function() {   
	setTemp();
	updateTemp();
	$("#targetTemperature").keypress(function(e) {
		if (e.which === 13) {
			db.openDoc(sensorName, {
				success : function(data) {
					data["target_temperature"] = $("#targetTemperature").val();
					db.saveDoc(data);
				}
			});
			return false;
		}
		return true;
	});
	setInterval(updateTemp, 5000);
});