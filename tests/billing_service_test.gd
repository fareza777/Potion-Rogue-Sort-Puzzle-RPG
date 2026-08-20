extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var original := SaveSystem.data.duplicate(true)
	SaveSystem.data = SaveSystem.DEFAULT_DATA.duplicate(true)
	BillingService.refresh_entitlement_from_save()
	check(BillingService.PRODUCT_ID == "potion_rogue_remove_ads",
			"billing uses the approved Remove Ads product id")
	check(BillingService.product_title() == "Remove Ads",
			"billing exposes the English fallback product title")
	check(BillingService.product_price() == "$4.99",
			"billing exposes the approved fallback price")
	check(not BillingService.is_entitled(),
			"fresh profiles do not start entitled")

	BillingService.call("_process_purchase", {
		"product_ids": PackedStringArray([BillingService.PRODUCT_ID]),
		"purchase_state": BillingClient.PurchaseState.PENDING,
		"is_acknowledged": false,
	})
	check(not BillingService.is_entitled(),
			"pending purchases never remove ads")

	BillingService.call("_process_purchase", {
		"product_ids": PackedStringArray([BillingService.PRODUCT_ID]),
		"purchase_state": BillingClient.PurchaseState.PURCHASED,
		"is_acknowledged": true,
	})
	check(BillingService.is_entitled(),
			"confirmed purchases remove ads")
	check(SaveSystem.ads_removed(),
			"confirmed purchases persist the entitlement")

	SaveSystem.data = SaveSystem.DEFAULT_DATA.duplicate(true)
	BillingService.refresh_entitlement_from_save()
	BillingService.call("_process_purchase", {
		"product_ids": PackedStringArray(["another_product"]),
		"purchase_state": BillingClient.PurchaseState.PURCHASED,
		"is_acknowledged": true,
	})
	check(not BillingService.is_entitled(),
			"unrelated products never remove ads")

	SaveSystem.data = SaveSystem.DEFAULT_DATA.duplicate(true)
	BillingService.refresh_entitlement_from_save()
	BillingService.call("_process_purchase", {
		"product_ids": PackedStringArray(["potion_rogue_full_campaign"]),
		"purchase_state": BillingClient.PurchaseState.PURCHASED,
		"is_acknowledged": true,
	})
	check(BillingService.is_entitled(),
			"legacy campaign buyers are honoured as Remove Ads owners")

	SaveSystem.data = original
	BillingService.refresh_entitlement_from_save()
	SaveSystem.save()
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)
