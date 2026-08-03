extends Node
## Autoload: BillingService
## Owns the Android Google Play Billing boundary for the one-time campaign
## unlock. The rest of the game only consumes entitlement/status signals, so
## desktop, editor, and headless builds remain playable without BillingClient.

const PRODUCT_ID := "potion_rogue_full_campaign"
const PRODUCT_TITLE := "Full Campaign Unlock"
const FALLBACK_PRICE := "$4.99"

signal entitlement_changed(unlocked: bool)
signal status_changed(message: String)
signal purchase_available(available: bool)

var _billing_client: BillingClient
var _available := false
var _product_ready := false
var _product: Dictionary = {}
var _entitled := false


func _ready() -> void:
	refresh_entitlement_from_save()
	if not OS.has_feature("android"):
		_set_status("Google Play purchases are available on Android.")
		return
	_billing_client = BillingClient.new()
	_billing_client.connected.connect(_on_connected)
	_billing_client.disconnected.connect(_on_disconnected)
	_billing_client.connect_error.connect(_on_connect_error)
	_billing_client.query_product_details_response.connect(
			_on_query_product_details_response)
	_billing_client.query_purchases_response.connect(_on_query_purchases_response)
	_billing_client.on_purchase_updated.connect(_on_purchase_updated)
	_billing_client.acknowledge_purchase_response.connect(
			_on_acknowledge_purchase_response)
	_billing_client.start_connection()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED:
		refresh_entitlement_from_save()
		if _available and _billing_client != null and _billing_client.is_ready():
			_billing_client.query_purchases(BillingClient.ProductType.INAPP)


func is_available() -> bool:
	return _available


func is_entitled() -> bool:
	return _entitled


func product_title() -> String:
	var title := str(_product.get("title", ""))
	return title if not title.is_empty() else PRODUCT_TITLE


func product_price() -> String:
	var direct_price := str(_product.get("formatted_price", ""))
	if not direct_price.is_empty():
		return direct_price
	var offer_list: Variant = _product.get("one_time_purchase_offer_details", [])
	if not offer_list.is_empty() and offer_list[0] is Dictionary:
		var offer: Dictionary = offer_list[0]
		var offer_price := str(offer.get("formatted_price", ""))
		if not offer_price.is_empty():
			return offer_price
	return FALLBACK_PRICE


func purchase_full_campaign() -> void:
	if _entitled:
		_set_status("Full Campaign Unlock is already active.")
		return
	if not _available or _billing_client == null:
		_set_status("Google Play purchases are available on Android.")
		return
	if not _product_ready:
		_set_status("The campaign offer is still loading. Please try again shortly.")
		return
	var launch: Dictionary = _billing_client.purchase(PRODUCT_ID)
	if int(launch.get("response_code", BillingClient.BillingResponseCode.ERROR)) \
			!= BillingClient.BillingResponseCode.OK:
		_set_status(_billing_message(launch, "Google Play could not start the purchase."))
	else:
		_set_status("Complete the purchase in Google Play.")


func restore_purchases() -> void:
	if not _available or _billing_client == null or not _billing_client.is_ready():
		_set_status("Restore Purchase is available on Android through Google Play.")
		return
	_set_status("Checking your Google Play purchases...")
	_billing_client.query_purchases(BillingClient.ProductType.INAPP)


func refresh_entitlement_from_save() -> void:
	var saved := SaveSystem.full_campaign_unlocked()
	if _entitled == saved:
		return
	_entitled = saved
	entitlement_changed.emit(_entitled)


func _on_connected() -> void:
	_available = true
	purchase_available.emit(_product_ready)
	_set_status("Google Play purchases are ready.")
	_billing_client.query_product_details(
			PackedStringArray([PRODUCT_ID]), BillingClient.ProductType.INAPP)
	_billing_client.query_purchases(BillingClient.ProductType.INAPP)


func _on_disconnected() -> void:
	_available = false
	_product_ready = false
	purchase_available.emit(false)
	_set_status("Google Play purchases are temporarily unavailable.")


func _on_connect_error(response_code: int, debug_message: String) -> void:
	_available = false
	purchase_available.emit(false)
	_set_status("Google Play is unavailable: %s" % debug_message)


func _on_query_product_details_response(response: Dictionary) -> void:
	if int(response.get("response_code", BillingClient.BillingResponseCode.ERROR)) \
			!= BillingClient.BillingResponseCode.OK:
		_product_ready = false
		_set_status(_billing_message(response, "The campaign offer is unavailable."))
		return
	var details: Array = response.get("product_details", [])
	_product_ready = false
	for item in details:
		if item is Dictionary and _product_id_from_details(item) == PRODUCT_ID:
			_product = item.duplicate(true)
			_product_ready = true
			break
	purchase_available.emit(_product_ready)
	if not _product_ready:
		_set_status("The campaign offer is not available yet.")


func _on_query_purchases_response(response: Dictionary) -> void:
	if int(response.get("response_code", BillingClient.BillingResponseCode.ERROR)) \
			!= BillingClient.BillingResponseCode.OK:
		_set_status(_billing_message(response, "Google Play could not restore purchases."))
		return
	for purchase in response.get("purchases", []):
		if purchase is Dictionary:
			_process_purchase(purchase)


func _on_purchase_updated(response: Dictionary) -> void:
	var response_code := int(response.get("response_code", BillingClient.BillingResponseCode.ERROR))
	if response_code == BillingClient.BillingResponseCode.USER_CANCELED:
		_set_status("Purchase canceled. Your campaign remains unchanged.")
		return
	if response_code != BillingClient.BillingResponseCode.OK:
		_set_status(_billing_message(response, "Google Play could not complete the purchase."))
		return
	for purchase in response.get("purchases", []):
		if purchase is Dictionary:
			_process_purchase(purchase)


func _process_purchase(purchase: Dictionary) -> void:
	if not _purchase_contains_product(purchase):
		return
	var state := int(purchase.get("purchase_state",
			BillingClient.PurchaseState.UNSPECIFIED_STATE))
	if state == BillingClient.PurchaseState.PENDING:
		_set_status("Purchase pending. Google Play will unlock the campaign after payment clears.")
		return
	if state != BillingClient.PurchaseState.PURCHASED:
		_set_status("Google Play has not confirmed this purchase.")
		return
	_grant_entitlement()
	var token := str(purchase.get("purchase_token", ""))
	if not bool(purchase.get("is_acknowledged", false)) and not token.is_empty():
		if _billing_client != null:
			_billing_client.acknowledge_purchase(token)
		_set_status("Full Campaign Unlock granted. Confirming the purchase with Google Play...")
	else:
		_set_status("Full Campaign Unlock is active.")


func _on_acknowledge_purchase_response(response: Dictionary) -> void:
	if int(response.get("response_code", BillingClient.BillingResponseCode.ERROR)) \
			== BillingClient.BillingResponseCode.OK:
		_set_status("Full Campaign Unlock is active.")
	else:
		_set_status(_billing_message(response,
				"The purchase is granted and will be confirmed again automatically."))


func _grant_entitlement() -> void:
	if _entitled:
		return
	_entitled = true
	SaveSystem.set_full_campaign_unlocked(true)
	entitlement_changed.emit(true)


func _purchase_contains_product(purchase: Dictionary) -> bool:
	var product_ids: Variant = purchase.get("product_ids", [])
	if product_ids is Array or product_ids is PackedStringArray:
		return PRODUCT_ID in product_ids
	return str(purchase.get("product_id", "")) == PRODUCT_ID


func _product_id_from_details(details: Dictionary) -> String:
	return str(details.get("product_id", details.get("productId", "")))


func _billing_message(response: Dictionary, fallback: String) -> String:
	var message := str(response.get("debug_message", ""))
	return message if not message.is_empty() else fallback


func _set_status(message: String) -> void:
	status_changed.emit(message)
