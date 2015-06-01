function(doc) {
	var interval = 600;
	if (doc.actual_temperature) { // measurement
		emit(doc.config_name + ":" + Math.floor(doc.unix_time / interval), doc);
	}
}