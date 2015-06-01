//var chartTemp = function() {
	function chart(divId, preparedData, dates) {
			var chart1 = {
				chart: {
					renderTo: divId,
				},
				title: {
					text: 'Temperature stats'
				},
				xAxis: {
					labels: {
						formatter: function() {
							return new Date(this.value * 1000);
						}
					},
					categories: dates
				},
				yAxis: [{
					labels: {
						formatter: function() {
							return this.value+ '°C';
						},
						style: {
							color: '#89A54E'
						}
					},
					title: {
						text: 'Temperature',
						style: {
							color: '#89A54E'
						}
					},
				}, {
					labels: {
						formatter: function() {
							return this.value +'%';
						},
						style: {
							color: '#4572A7'
						}
					},
					title: {
						text: 'Humidity',
						style: {
							color: '#4572A7'
						}
					}
				} , {
					labels: {
						formatter: function() {
							return this.value ? 100 : 0;
						},
						style: {
	                        color: '#AA4643'
						}
					},
					title: {
						text: 'Heater on',
						style: {
	                        color: '#AA4643'
						}
					}
				}],
				tooltip: {
					formatter: function() {
						var unit = {
								'Temperature': '°C',
								'Humidity': '%',
								'Heater on': ''
						}[this.series.name];
						return ''+
						this.x +': '+ this.y +' '+ unit;
					}
				},
				legend: {
					layout: 'vertical',
					align: 'left',
					x: 120,
					verticalAlign: 'top',
					y: 80,
					floating: true,
					backgroundColor: '#FFFFFF'
				},
				series: preparedData
			};
			new Highcharts.Chart(chart1);
	};
	function drawChart(divId) {
			var path = unescape(document.location.pathname).split('/');
			var design = path[3];
			db = $.couch.db(path[1]);
			db.view(design + "/list_measurements", {
				descending : "true",
// limit : 50,
				update_seq : true,
				success : function(data) {
					var preparedData = [
					                    {name: 'temperature', type: 'spline', data:[]},
					                    {name: 'humidity', type: 'spline', data:[]},
					                    {name: 'heater on', type: 'area', data:[]},
					                    ];
					var dates = [];
					var len = data.rows.length;
					var chunk = data.rows.length / 100;
					var index = 0;
					var pos = 0;
					data.rows.forEach(function(doc) {
						if (Math.floor(chunk * index) >= pos) {
							index++;
							preparedData[0]['data'].push(parseFloat(doc['value']['actual_temperature']));
							preparedData[1]['data'].push(parseFloat(doc['value']['actual_humidity']));
							preparedData[2]['data'].push((doc['value']['heater_on'] === 'true')?100:0);
							dates.push(doc['value']['unix_time']);
						}
						pos++;
					});
					chart(divId, preparedData, dates);
				}
			});	
	};
//};
	


$(function() {   
	drawChart('content');
});
