package com.farshadghanzanfari.promoneymanager.backup

import com.farshadghanzanfari.promoneymanager.core.model.Account
import com.farshadghanzanfari.promoneymanager.core.model.AccountId
import com.farshadghanzanfari.promoneymanager.core.model.AccountType
import com.farshadghanzanfari.promoneymanager.core.model.AttachmentId
import com.farshadghanzanfari.promoneymanager.core.model.BackupManifest
import com.farshadghanzanfari.promoneymanager.core.model.BackupRecordType
import com.farshadghanzanfari.promoneymanager.core.model.Budget
import com.farshadghanzanfari.promoneymanager.core.model.BudgetId
import com.farshadghanzanfari.promoneymanager.core.model.Category
import com.farshadghanzanfari.promoneymanager.core.model.CategoryId
import com.farshadghanzanfari.promoneymanager.core.model.CompleteBackupSnapshot
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.DebtPayoffPlan
import com.farshadghanzanfari.promoneymanager.core.model.DebtPayoffStrategy
import com.farshadghanzanfari.promoneymanager.core.model.DebtPlanId
import com.farshadghanzanfari.promoneymanager.core.model.GoalContributionId
import com.farshadghanzanfari.promoneymanager.core.model.ImportBatchId
import com.farshadghanzanfari.promoneymanager.core.model.MatchType
import com.farshadghanzanfari.promoneymanager.core.model.MerchantRule
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoal
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoalContribution
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoalContributionDirection
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoalId
import com.farshadghanzanfari.promoneymanager.core.model.ScheduleFrequency
import com.farshadghanzanfari.promoneymanager.core.model.ScheduleId
import com.farshadghanzanfari.promoneymanager.core.model.ScheduleStatus
import com.farshadghanzanfari.promoneymanager.core.model.ScheduledTransaction
import com.farshadghanzanfari.promoneymanager.core.model.Tag
import com.farshadghanzanfari.promoneymanager.core.model.TagId
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import com.farshadghanzanfari.promoneymanager.core.model.TransactionAttachment
import com.farshadghanzanfari.promoneymanager.core.model.TransactionId
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import com.farshadghanzanfari.promoneymanager.core.model.TransactionSourceMetadata
import com.farshadghanzanfari.promoneymanager.core.model.TransactionSplitAllocation
import com.farshadghanzanfari.promoneymanager.core.model.TransferDirection
import com.farshadghanzanfari.promoneymanager.core.model.TransferId
import com.farshadghanzanfari.promoneymanager.core.model.SplitId
import java.time.Instant
import java.time.LocalDate
import java.time.YearMonth
import org.json.JSONArray
import org.json.JSONObject

class BackupFormatException(message: String, cause: Throwable? = null) :
    IllegalArgumentException(message, cause)

/**
 * Serializes the complete local backup snapshot to a self-contained JSON document
 * and back. The schema version travels in the manifest so restores can refuse
 * documents produced by newer app versions before touching the database.
 */
object BackupCodec {
    fun encode(snapshot: CompleteBackupSnapshot): String {
        val root = JSONObject()
        root.put(
            "manifest",
            JSONObject().apply {
                put("schemaVersion", snapshot.manifest.schemaVersion)
                put("createdAt", snapshot.manifest.createdAt.toString())
                put("packageName", snapshot.manifest.packageName)
                put(
                    "recordCounts",
                    JSONObject().apply {
                        snapshot.manifest.recordCounts.forEach { (type, count) -> put(type.name, count) }
                    },
                )
            },
        )
        root.put("accounts", JSONArray(snapshot.accounts.map(::encodeAccount)))
        root.put("categories", JSONArray(snapshot.categories.map(::encodeCategory)))
        root.put("tags", JSONArray(snapshot.tags.map(::encodeTag)))
        root.put("transactions", JSONArray(snapshot.transactions.map(::encodeTransaction)))
        root.put("merchantRules", JSONArray(snapshot.merchantRules.map(::encodeRule)))
        root.put("budgets", JSONArray(snapshot.budgets.map(::encodeBudget)))
        root.put("scheduledTransactions", JSONArray(snapshot.scheduledTransactions.map(::encodeSchedule)))
        root.put("savingsGoals", JSONArray(snapshot.savingsGoals.map(::encodeGoal)))
        root.put("savingsGoalContributions", JSONArray(snapshot.savingsGoalContributions.map(::encodeContribution)))
        root.put("debtPayoffPlans", JSONArray(snapshot.debtPayoffPlans.map(::encodeDebtPlan)))
        return root.toString(2)
    }

    fun decode(json: String): CompleteBackupSnapshot {
        val root = runCatching { JSONObject(json) }
            .getOrElse { throw BackupFormatException("The selected file is not a valid backup document.", it) }
        val manifestJson = root.optJSONObject("manifest")
            ?: throw BackupFormatException("The backup file is missing its manifest.")
        val schemaVersion = manifestJson.optInt("schemaVersion", -1)
        if (schemaVersion > BackupManifest.CURRENT_SCHEMA_VERSION) {
            throw BackupFormatException("Backup version $schemaVersion is newer than this app supports.")
        }
        if (schemaVersion < 1) {
            throw BackupFormatException("The backup file has an invalid schema version.")
        }
        return try {
            val countsJson = manifestJson.optJSONObject("recordCounts") ?: JSONObject()
            val counts = buildMap {
                countsJson.keys().forEach { key ->
                    runCatching { BackupRecordType.valueOf(key) }
                        .onSuccess { put(it, countsJson.getInt(key)) }
                }
            }
            CompleteBackupSnapshot(
                manifest = BackupManifest(
                    schemaVersion = schemaVersion,
                    createdAt = Instant.parse(manifestJson.getString("createdAt")),
                    recordCounts = counts,
                ),
                accounts = root.list("accounts", ::decodeAccount),
                categories = root.list("categories", ::decodeCategory),
                tags = root.list("tags", ::decodeTag),
                transactions = root.list("transactions", ::decodeTransaction),
                merchantRules = root.list("merchantRules", ::decodeRule),
                budgets = root.list("budgets", ::decodeBudget),
                scheduledTransactions = root.list("scheduledTransactions", ::decodeSchedule),
                savingsGoals = root.list("savingsGoals", ::decodeGoal),
                savingsGoalContributions = root.list("savingsGoalContributions", ::decodeContribution),
                debtPayoffPlans = root.list("debtPayoffPlans", ::decodeDebtPlan),
            )
        } catch (error: BackupFormatException) {
            throw error
        } catch (error: Exception) {
            throw BackupFormatException("The backup file contains invalid records.", error)
        }
    }

    private fun <T> JSONObject.list(key: String, decoder: (JSONObject) -> T): List<T> {
        val array = optJSONArray(key) ?: return emptyList()
        return (0 until array.length()).map { decoder(array.getJSONObject(it)) }
    }

    private fun encodeMoney(money: Money) = JSONObject()
        .put("minorUnits", money.minorUnits)
        .put("currency", money.currency.value)

    private fun decodeMoney(json: JSONObject) = Money(
        minorUnits = json.getLong("minorUnits"),
        currency = CurrencyCode.of(json.getString("currency")),
    )

    private fun JSONObject.putNullable(key: String, value: Any?): JSONObject =
        if (value != null) put(key, value) else this

    private fun JSONObject.stringOrNull(key: String): String? =
        if (has(key) && !isNull(key)) getString(key) else null

    private fun encodeAccount(account: Account) = JSONObject()
        .put("id", account.id.value)
        .put("name", account.name)
        .put("currency", account.currency.value)
        .put("openingBalance", encodeMoney(account.openingBalance))
        .put("type", account.type.name)
        .put("isArchived", account.isArchived)

    private fun decodeAccount(json: JSONObject) = Account(
        id = AccountId(json.getString("id")),
        name = json.getString("name"),
        currency = CurrencyCode.of(json.getString("currency")),
        openingBalance = decodeMoney(json.getJSONObject("openingBalance")),
        type = AccountType.valueOf(json.getString("type")),
        isArchived = json.optBoolean("isArchived", false),
    )

    private fun encodeCategory(category: Category) = JSONObject()
        .put("id", category.id.value)
        .put("name", category.name)
        .put("kind", category.kind.name)
        .putNullable("parentId", category.parentId?.value)
        .put("sortOrder", category.sortOrder)
        .put("isArchived", category.isArchived)

    private fun decodeCategory(json: JSONObject) = Category(
        id = CategoryId(json.getString("id")),
        name = json.getString("name"),
        kind = TransactionKind.valueOf(json.getString("kind")),
        parentId = json.stringOrNull("parentId")?.let(::CategoryId),
        sortOrder = json.optInt("sortOrder", 0),
        isArchived = json.optBoolean("isArchived", false),
    )

    private fun encodeTag(tag: Tag) = JSONObject()
        .put("id", tag.id.value)
        .put("name", tag.name)
        .put("colorHex", tag.colorHex)

    private fun decodeTag(json: JSONObject) = Tag(
        id = TagId(json.getString("id")),
        name = json.getString("name"),
        colorHex = json.optString("colorHex", "8151D1"),
    )

    private fun encodeTransaction(transaction: Transaction) = JSONObject()
        .put("id", transaction.id.value)
        .put("accountId", transaction.accountId.value)
        .put("amount", encodeMoney(transaction.amount))
        .put("kind", transaction.kind.name)
        .put("localDate", transaction.localDate.toString())
        .put("merchant", transaction.merchant)
        .put("normalizedMerchant", transaction.normalizedMerchant)
        .put("note", transaction.note)
        .putNullable("categoryId", transaction.categoryId?.value)
        .putNullable("subcategoryId", transaction.subcategoryId?.value)
        .put("tagIds", JSONArray(transaction.tagIds.map { it.value }))
        .put(
            "attachments",
            JSONArray(
                transaction.attachments.map { attachment ->
                    JSONObject()
                        .put("id", attachment.id.value)
                        .put("fileName", attachment.fileName)
                        .put("originalFileName", attachment.originalFileName)
                        .put("contentType", attachment.contentType)
                        .put("createdAt", attachment.createdAt.toString())
                },
            ),
        )
        .putNullable(
            "source",
            transaction.source?.let { source ->
                JSONObject()
                    .putNullable("sourceName", source.sourceName)
                    .putNullable("sourceRow", source.sourceRow)
                    .put("rawDescription", source.rawDescription)
                    .putNullable("importBatchId", source.importBatchId?.value)
            },
        )
        .put(
            "splitAllocations",
            JSONArray(
                transaction.splitAllocations.map { split ->
                    JSONObject()
                        .put("id", split.id.value)
                        .put("categoryId", split.categoryId.value)
                        .put("amount", encodeMoney(split.amount))
                        .putNullable("subcategoryId", split.subcategoryId?.value)
                },
            ),
        )
        .putNullable("transferId", transaction.transferId?.value)
        .putNullable("transferDirection", transaction.transferDirection?.name)

    private fun decodeTransaction(json: JSONObject): Transaction {
        val tagIds = json.optJSONArray("tagIds")?.let { array ->
            (0 until array.length()).map { TagId(array.getString(it)) }
        } ?: emptyList()
        val attachments = json.optJSONArray("attachments")?.let { array ->
            (0 until array.length()).map { index ->
                val item = array.getJSONObject(index)
                TransactionAttachment(
                    id = AttachmentId(item.getString("id")),
                    fileName = item.getString("fileName"),
                    originalFileName = item.getString("originalFileName"),
                    contentType = item.getString("contentType"),
                    createdAt = Instant.parse(item.getString("createdAt")),
                )
            }
        } ?: emptyList()
        val splits = json.optJSONArray("splitAllocations")?.let { array ->
            (0 until array.length()).map { index ->
                val item = array.getJSONObject(index)
                TransactionSplitAllocation(
                    id = SplitId(item.getString("id")),
                    categoryId = CategoryId(item.getString("categoryId")),
                    amount = decodeMoney(item.getJSONObject("amount")),
                    subcategoryId = item.stringOrNull("subcategoryId")?.let(::CategoryId),
                )
            }
        } ?: emptyList()
        val source = json.optJSONObject("source")?.let { item ->
            TransactionSourceMetadata(
                sourceName = item.stringOrNull("sourceName"),
                sourceRow = if (item.has("sourceRow") && !item.isNull("sourceRow")) item.getInt("sourceRow") else null,
                rawDescription = item.optString("rawDescription", ""),
                importBatchId = item.stringOrNull("importBatchId")?.let(::ImportBatchId),
            )
        }
        return Transaction(
            id = TransactionId(json.getString("id")),
            accountId = AccountId(json.getString("accountId")),
            amount = decodeMoney(json.getJSONObject("amount")),
            kind = TransactionKind.valueOf(json.getString("kind")),
            localDate = LocalDate.parse(json.getString("localDate")),
            merchant = json.getString("merchant"),
            normalizedMerchant = json.optString("normalizedMerchant", json.getString("merchant").trim().uppercase()),
            note = json.optString("note", ""),
            categoryId = json.stringOrNull("categoryId")?.let(::CategoryId),
            subcategoryId = json.stringOrNull("subcategoryId")?.let(::CategoryId),
            tagIds = tagIds,
            attachments = attachments,
            source = source,
            splitAllocations = splits,
            transferId = json.stringOrNull("transferId")?.let(::TransferId),
            transferDirection = json.stringOrNull("transferDirection")?.let(TransferDirection::valueOf),
        )
    }

    private fun encodeRule(rule: MerchantRule) = JSONObject()
        .put("id", rule.id)
        .put("pattern", rule.pattern)
        .put("matchType", rule.matchType.name)
        .put("categoryId", rule.categoryId.value)
        .putNullable("subcategoryId", rule.subcategoryId?.value)
        .put("kind", rule.kind.name)
        .put("confidence", rule.confidence)
        .put("sampleCount", rule.sampleCount)
        .put("isEnabled", rule.isEnabled)
        .putNullable("accountId", rule.accountId?.value)
        .putNullable("notePattern", rule.notePattern)
        .putNullable("minAmount", rule.minAmount?.let(::encodeMoney))
        .putNullable("maxAmount", rule.maxAmount?.let(::encodeMoney))
        .put("priority", rule.priority)
        .put("isAutoGenerated", rule.isAutoGenerated)

    private fun decodeRule(json: JSONObject) = MerchantRule(
        id = json.getString("id"),
        pattern = json.getString("pattern"),
        matchType = MatchType.valueOf(json.optString("matchType", MatchType.CONTAINS.name)),
        categoryId = CategoryId(json.getString("categoryId")),
        subcategoryId = json.stringOrNull("subcategoryId")?.let(::CategoryId),
        kind = TransactionKind.valueOf(json.optString("kind", TransactionKind.EXPENSE.name)),
        confidence = json.optDouble("confidence", 0.7),
        sampleCount = json.optInt("sampleCount", 0),
        isEnabled = json.optBoolean("isEnabled", true),
        accountId = json.stringOrNull("accountId")?.let(::AccountId),
        notePattern = json.stringOrNull("notePattern"),
        minAmount = json.optJSONObject("minAmount")?.let(::decodeMoney),
        maxAmount = json.optJSONObject("maxAmount")?.let(::decodeMoney),
        priority = json.optInt("priority", 0),
        isAutoGenerated = json.optBoolean("isAutoGenerated", false),
    )

    private fun encodeBudget(budget: Budget) = JSONObject()
        .put("id", budget.id.value)
        .put("categoryId", budget.categoryId.value)
        .put("month", budget.month.toString())
        .put("amount", encodeMoney(budget.amount))
        .putNullable("subcategoryId", budget.subcategoryId?.value)
        .put("rolloverEnabled", budget.rolloverEnabled)
        .put("isArchived", budget.isArchived)

    private fun decodeBudget(json: JSONObject) = Budget(
        id = BudgetId(json.getString("id")),
        categoryId = CategoryId(json.getString("categoryId")),
        month = YearMonth.parse(json.getString("month")),
        amount = decodeMoney(json.getJSONObject("amount")),
        subcategoryId = json.stringOrNull("subcategoryId")?.let(::CategoryId),
        rolloverEnabled = json.optBoolean("rolloverEnabled", false),
        isArchived = json.optBoolean("isArchived", false),
    )

    private fun encodeSchedule(schedule: ScheduledTransaction) = JSONObject()
        .put("id", schedule.id.value)
        .put("accountId", schedule.accountId.value)
        .put("amount", encodeMoney(schedule.amount))
        .put("kind", schedule.kind.name)
        .put("merchant", schedule.merchant)
        .put("normalizedMerchant", schedule.normalizedMerchant)
        .putNullable("categoryId", schedule.categoryId?.value)
        .putNullable("subcategoryId", schedule.subcategoryId?.value)
        .put("note", schedule.note)
        .put("frequency", schedule.frequency.name)
        .put("nextDate", schedule.nextDate.toString())
        .putNullable("lastRunDate", schedule.lastRunDate?.toString())
        .put("status", schedule.status.name)
        .put("reminderEnabled", schedule.reminderEnabled)

    private fun decodeSchedule(json: JSONObject) = ScheduledTransaction(
        id = ScheduleId(json.getString("id")),
        accountId = AccountId(json.getString("accountId")),
        amount = decodeMoney(json.getJSONObject("amount")),
        kind = TransactionKind.valueOf(json.getString("kind")),
        merchant = json.getString("merchant"),
        normalizedMerchant = json.optString("normalizedMerchant", json.getString("merchant").trim().uppercase()),
        categoryId = json.stringOrNull("categoryId")?.let(::CategoryId),
        subcategoryId = json.stringOrNull("subcategoryId")?.let(::CategoryId),
        note = json.optString("note", ""),
        frequency = ScheduleFrequency.valueOf(json.getString("frequency")),
        nextDate = LocalDate.parse(json.getString("nextDate")),
        lastRunDate = json.stringOrNull("lastRunDate")?.let(LocalDate::parse),
        status = ScheduleStatus.valueOf(json.optString("status", ScheduleStatus.ACTIVE.name)),
        reminderEnabled = json.optBoolean("reminderEnabled", false),
    )

    private fun encodeGoal(goal: SavingsGoal) = JSONObject()
        .put("id", goal.id.value)
        .put("name", goal.name)
        .put("targetAmount", encodeMoney(goal.targetAmount))
        .put("currentAmount", encodeMoney(goal.currentAmount))
        .putNullable("targetDate", goal.targetDate?.toString())
        .put("isArchived", goal.isArchived)

    private fun decodeGoal(json: JSONObject) = SavingsGoal(
        id = SavingsGoalId(json.getString("id")),
        name = json.getString("name"),
        targetAmount = decodeMoney(json.getJSONObject("targetAmount")),
        currentAmount = decodeMoney(json.getJSONObject("currentAmount")),
        targetDate = json.stringOrNull("targetDate")?.let(LocalDate::parse),
        isArchived = json.optBoolean("isArchived", false),
    )

    private fun encodeContribution(contribution: SavingsGoalContribution) = JSONObject()
        .put("id", contribution.id.value)
        .put("goalId", contribution.goalId.value)
        .put("amount", encodeMoney(contribution.amount))
        .put("direction", contribution.direction.name)
        .put("localDate", contribution.localDate.toString())
        .put("note", contribution.note)

    private fun decodeContribution(json: JSONObject) = SavingsGoalContribution(
        id = GoalContributionId(json.getString("id")),
        goalId = SavingsGoalId(json.getString("goalId")),
        amount = decodeMoney(json.getJSONObject("amount")),
        direction = SavingsGoalContributionDirection.valueOf(json.getString("direction")),
        localDate = LocalDate.parse(json.getString("localDate")),
        note = json.optString("note", ""),
    )

    private fun encodeDebtPlan(plan: DebtPayoffPlan) = JSONObject()
        .put("id", plan.id.value)
        .put("name", plan.name)
        .put("originalBalance", encodeMoney(plan.originalBalance))
        .put("currentBalance", encodeMoney(plan.currentBalance))
        .put("annualInterestRateBasisPoints", plan.annualInterestRateBasisPoints)
        .put("minimumPayment", encodeMoney(plan.minimumPayment))
        .put("extraPayment", encodeMoney(plan.extraPayment))
        .put("strategy", plan.strategy.name)
        .put("isArchived", plan.isArchived)

    private fun decodeDebtPlan(json: JSONObject) = DebtPayoffPlan(
        id = DebtPlanId(json.getString("id")),
        name = json.getString("name"),
        originalBalance = decodeMoney(json.getJSONObject("originalBalance")),
        currentBalance = decodeMoney(json.getJSONObject("currentBalance")),
        annualInterestRateBasisPoints = json.optInt("annualInterestRateBasisPoints", 0),
        minimumPayment = decodeMoney(json.getJSONObject("minimumPayment")),
        extraPayment = decodeMoney(json.getJSONObject("extraPayment")),
        strategy = DebtPayoffStrategy.valueOf(json.getString("strategy")),
        isArchived = json.optBoolean("isArchived", false),
    )
}
