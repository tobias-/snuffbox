function(doc) {
	if (doc.config_name) {
		emit(doc.config_name, null);
	}
}