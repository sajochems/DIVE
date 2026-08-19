extends Node


@onready var http := HTTPRequest.new()

func _ready():
	add_child(http)
	http.request_completed.connect(_on_request_completed)
	
	test_connection()


func _on_request_completed(result, response_code, headers, body):
	if result == OK:
		AppLogger.log("Marker received")

	#AppLogger.log("----- BIOPAC RESPONSE -----")
	#AppLogger.log("Result code: " + str(result))
	#AppLogger.log("HTTP response code: " + str(response_code))
	#AppLogger.log("Headers: " + str(headers))
	##AppLogger.log("Body: \n" + body.get_string_from_utf8())
	#AppLogger.log("----------------------------")


func send_xml_rpc(xml):

	#AppLogger.log("Sending XML RPC to BIOPAC:")
	#AppLogger.log(xml)

	var error = http.request(
		Global.acqknowledge_url,
		["Content-Type: text/xml"],
		HTTPClient.METHOD_POST,
		xml
	)

	if error != OK:
		AppLogger.err("HTTPRequest failed to start. Error: " + str(error))



# -------------------------
# MARKER FUNCTION
# -------------------------

func send_marker(label: String):

	AppLogger.log("Sending marker: " + label)

	var xml := "<?xml version=\"1.0\"?>"
	xml += "<methodCall>"
	xml += "<methodName>acq.insertGlobalEvent</methodName>"
	xml += "<params>"
	xml += "<param><value><string>%s</string></value></param>" % label
	xml += "<param><value><string>marker</string></value></param>"
	xml += "<param><value><string></string></value></param>"
	xml += "</params>"
	xml += "</methodCall>"

	send_xml_rpc(xml)

# -------------------------
# CONNECTION TEST
# -------------------------

func test_connection():

	AppLogger.log("Testing connection to BIOPAC RPC server...")

	var xml := "<?xml version=\"1.0\"?>"
	xml += "<methodCall>"
	xml += "<methodName>system.listMethods</methodName>"
	xml += "<params></params>"
	xml += "</methodCall>"

	send_xml_rpc(xml)
