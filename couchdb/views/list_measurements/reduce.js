function (keys, values, rereduce) {
	var avgFields = ['actual_humidity', 'target_temperature', 'actual_temperature'];
	var returnValue = {};
	for (var i in values[0])
	 returnValue[i] = values[0][i];
	
	var length = 0;
	for(var value in values) {
		length++;
		for (var x in avgFields) {
			returnValue[x] += values[value][x];
		}
	}
	if (length > 0) {
		for (var x in avgFields) {
			returnValue[x] = returnValue[x] / length;
		}
	}
	return returnValue;
}