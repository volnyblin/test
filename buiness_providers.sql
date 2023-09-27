WITH
	aaf AS (
	SELECT
	CASE WHEN c."idClientGroup" IN (3116, 3120) THEN 'ECardon'
	WHEN c."idClientGroup" = 3147 THEN 'Drexler'
	WHEN c."idClientGroup" = 3114 THEN 'Shradda'
	WHEN c."idClientGroup" = 3020 THEN 'EMerchantPay'
	WHEN c."idClientGroup" IN (2872, 2906, 3046, 3058) THEN 'Apexx'
	WHEN c."idClientGroup" IN (2630, 2674) THEN 'Fxpay'
	WHEN c."idClientGroup" IN (2772, 2878, 2882, 2972) THEN 'Ocon'
	WHEN c."idClientGroup" IN (2974, 2976, 2980, 2982) THEN 'Cetler'
	WHEN c."idClientGroup" = 3018 THEN 'C4 Labs Eood'
	WHEN c."idClientGroup" = 2928 THEN 'Ixopay'
	WHEN c."idClientGroup" IN (238, 594, 886, 930, 1484, 2022, 2076, 2166, 2420, 2546, 2622, 2700, 2714, 2720, 2724, 2746, 2770, 2806, 2818, 2962) THEN 'Oney'
	END AS provider,
	a."sourceId"
	FROM dw.accounts a
	LEFT JOIN dw.accountBillingData abd ON a."sourceId" = abd."idAccount"
	LEFT JOIN dw.clients c ON c."sourceId" = a."idClient"
	WHERE c."idClientGroup" IN (3116, 3120) -- ECardon
	OR c."idClientGroup" = 3147 -- Drexler
	OR c."idClientGroup" = 3114 -- Shradda
	OR c."idClientGroup" = 3020 -- EMerchantPay
	OR (c."idClientGroup" IN (2872, 2906, 3046, 3058) AND abd."mode" = 'icplusplus') -- Apexx
	OR c."idClientGroup" IN (2630, 2674) -- Fxpay
	OR c."idClientGroup" IN (2772, 2878, 2882, 2972) -- Ocon
	OR c."idClientGroup" IN (2974, 2976, 2980, 2982) -- Cetler
	OR (c."idClientGroup" = 3018 AND abd."mode" = 'icplusplus') -- C4 Labs Eood
	OR c."idClientGroup" = 2928 -- Ixopay
	OR c."idClientGroup" IN (238, 594, 886, 930, 1484, 2022, 2076, 2166, 2420, 2546, 2622, 2700, 2714, 2720, 2724, 2746, 2770, 2806, 2818, 2962) -- Oney
	)
	
SELECT
aaf.provider AS 'Apporteur',
cg."name" AS 'Client Group Name',
c."name" AS 'Client Name',
a."supplier" AS 'Supplier',
a."processingCurrency" AS 'Processing Currency',
abd."currency" AS 'Settlement Currency',
aad."idStandardInvoiceMode",
CASE

WHEN aaf."provider" = 'Shradda' THEN
	CASE WHEN td."operationType" IN ('capture', 'payment') AND execCodes = '0' THEN
		CASE
		WHEN td."network" IN ('CB', 'VISA', 'MASTERCARD') THEN GREATEST((td."appliedCommissionAmountFix" + td."appliedCommisionAmountVar") / 2, 0)
		ELSE 0 END -- autre réseaux ? ajouter factu add après
	ELSE 0 END


WHEN aaf."provider" IN ('ECardon', 'Drexler', 'EMerchantPay') THEN -- réseau FPU ? revenu on cbk rpst setupfees ?
	CASE WHEN td."operationType" IN ('capture', 'payment') AND execCodes = '0' THEN
		CASE
		WHEN td."network" = 'CB' THEN GREATEST(((td."appliedCommissionAmountFix" + td."appliedCommisionAmountVar") - 0.05) / 2, 0)
		WHEN td."network" IN ('VISA', 'MASTERCARD') THEN GREATEST(((td."appliedCommissionAmountFix" + td."appliedCommisionAmountVar") - (0.0005 * amount + 0.05)) / 2, 0)
		ELSE 0 END -- autre réseaux ?
	ELSE 0 END


WHEN aaf."provider" = 'Apexx' THEN
	CASE
	WHEN td."execCodes" = '0' THEN
		CASE
		WHEN a."supplier" = 'Galitt' THEN GREATEST((td."appliedCommissionAmountFix" - 0.05) / 2, 0)
		WHEN a."supplier" IN ('Credorax', 'Bambora') THEN GREATEST((td."appliedCommissionAmountFix" - 0.07) / 2, 0)
		ELSE 0 END
	ELSE 0 END

WHEN aaf."provider" = 'C4 Labs Eood' THEN
	CASE
	WHEN td."execCodes" = '0' THEN
		CASE
		WHEN a."supplier" = 'Galitt' THEN GREATEST((td."appliedCommissionAmountFix" - 0.05) / 2, 0)
		WHEN a."supplier" IN ('Credorax', 'Bambora') THEN GREATEST((td."appliedCommissionAmountFix" - (0.0005 * td."amountInEur" + 0.07)) / 2, 0)
		ELSE 0 END
	ELSE 0 END

WHEN aaf."provider" = 'Cetler' THEN
	CASE
	WHEN td."operationType" IN ('capture', 'payment') AND td."execCodes" = '0' THEN GREATEST((td."appliedCommissionAmountFix" - 0.05) * 0.6, 0)
	ELSE 0 END

WHEN aaf."provider" = 'Fxpay' THEN
	CASE
	WHEN a."supplier" = 'Galitt' THEN 
		CASE
		WHEN td."billingNetwork" = 'Domestic' THEN GREATEST((td."appliedCommissionAmountFix" - td."amountInEur" * 0.29/100) * 0.5, 0)
		WHEN td."billingNetwork" = 'European' THEN GREATEST((td."appliedCommissionAmountFix" - td."amountInEur" * 0.8/100) * 0.5, 0)
		ELSE GREATEST((td."appliedCommissionAmountFix" - td."amountInEur" * 1.2/100) * 0.5, 0)
		END
	ELSE GREATEST((td."appliedCommissionAmountFix" - td."interchangeAmount") * 0.5, 0)
	END

WHEN aaf."provider" = 'Oney' THEN
	CASE
	WHEN a."supplier" = 'Oney' AND td."operationType" IN ('capture', 'payment') AND td."execCodes" = '0' THEN td."amountInEur" * 0.0013
	ELSE 0 END
	
WHEN aaf."provider" = 'Ocon' THEN
	CASE WHEN "execCodes" = '0' THEN
		CASE 
		WHEN abd."mode" = 'bundle' THEN
			CASE 
			WHEN a."supplier" = 'Galitt' THEN
				CASE 
				WHEN "billingNetwork" = 'Domestic' THEN GREATEST((td."appliedCommissionAmountFix" - ("amountInEur" * 0.004 + 0.05))/2, 0)
				WHEN "billingNetwork" = 'European' THEN GREATEST((td."appliedCommissionAmountFix" - ("amountInEur" * 0.008 + 0.05))/2, 0)
				WHEN "billingNetwork" = 'Internationnal' THEN GREATEST((td."appliedCommissionAmountFix" - ("amountInEur" * 0.022 + 0.05))/2, 0)
				ELSE 0 END
			WHEN "supplier" IN ('Credorax', 'Bambora') THEN GREATEST((td."appliedCommissionAmountFix" - 0.07)/2, 0)
			ELSE 0 END
		
		WHEN abd."mode" = 'icplus' THEN
			CASE 
			WHEN a."supplier" = 'Galitt' THEN 
				CASE WHEN "billingNetwork" = 'Domestic' THEN GREATEST((td."appliedCommissionAmountFix" - ("amountInEur" * 0.0005 + 0.05))/2, 0)
				WHEN "billingNetwork" = 'European' THEN GREATEST((td."appliedCommissionAmountFix" - ("amountInEur" * 0.002 + 0.05))/2, 0)
				WHEN "billingNetwork" = 'Internationnal' THEN GREATEST((td."appliedCommissionAmountFix" - ("amountInEur" * 0.0065 + 0.05))/2, 0)
				ELSE 0 END
			WHEN "supplier" IN ('Credorax', 'Bambora') THEN GREATEST((td."appliedCommissionAmountFix" - 0.07)/2, 0)
			ELSE 0 END
			
		WHEN abd."mode" = 'icplusplus' THEN
			CASE  
			WHEN a."supplier" = 'Galitt' THEN GREATEST((td."appliedCommissionAmountFix" - 0.05)/2, 0)
			WHEN a."supplier" IN ('Credorax', 'Bambora') THEN GREATEST((td."appliedCommissionAmountFix" - 0.07)/2, 0)
			ELSE 0 END
		
		ELSE 0 END
	ELSE 0 END

ELSE 0 END AS Commission
FROM dm.Finance td
INNER JOIN aaf ON td.idAccount = aaf."sourceId"
LEFT JOIN dw.exchangeRates er ON td."idEurExchangeRate" = er."id"
LEFT JOIN dw.accounts a ON td."idAccount" = a."sourceId"
LEFT JOIN dw.AccountAcquirerData aad ON a."sourceId" = aad."idAccount"
LEFT JOIN dw.accountBillingData abd ON a."sourceId" = abd."idAccount"
LEFT JOIN dw.clients c ON c."sourceId" = a."idClient"
LEFT JOIN dw.clientGroups cg ON cg."sourceId" = c."idClientGroup"
WHERE 1=1
AND td."receiveDate" >= '2023-09-03 00:00:00'
LIMIT 100;