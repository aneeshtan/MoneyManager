package com.farshadghanzanfari.promoneymanager.core.domain

import com.farshadghanzanfari.promoneymanager.core.model.CategoryId
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind

data class DefaultCategoryDefinition(
    val id: CategoryId,
    val name: String,
    val kind: TransactionKind,
    val parentId: CategoryId?,
    val sortOrder: Int,
)

// Shared by DefaultWorkspaceSeeder and MerchantCategoryFallbacks so fallback ids always exist.
object DefaultCategories {
    private fun top(id: String, name: String, kind: TransactionKind, sortOrder: Int) =
        DefaultCategoryDefinition(CategoryId(id), name, kind, null, sortOrder)

    private fun sub(id: String, name: String, kind: TransactionKind, parentId: String, sortOrder: Int) =
        DefaultCategoryDefinition(CategoryId(id), name, kind, CategoryId(parentId), sortOrder)

    val all: List<DefaultCategoryDefinition> = listOf(
        top("category-income", "Income", TransactionKind.INCOME, 10),
        sub("category-salary", "Salary", TransactionKind.INCOME, "category-income", 11),
        sub("category-bonus", "Bonus", TransactionKind.INCOME, "category-income", 12),
        sub("category-refunds", "Refunds", TransactionKind.INCOME, "category-income", 13),
        sub("category-cashback", "Cashback", TransactionKind.INCOME, "category-income", 14),
        sub("category-other-income", "Other Income", TransactionKind.INCOME, "category-income", 15),

        top("category-food", "Food", TransactionKind.EXPENSE, 20),
        sub("category-groceries", "Groceries", TransactionKind.EXPENSE, "category-food", 21),
        sub("category-restaurants", "Restaurants", TransactionKind.EXPENSE, "category-food", 22),
        sub("category-coffee", "Coffee", TransactionKind.EXPENSE, "category-food", 23),
        sub("category-delivery", "Delivery", TransactionKind.EXPENSE, "category-food", 24),

        top("category-transportation", "Transportation", TransactionKind.EXPENSE, 30),
        sub("category-taxi", "Taxi", TransactionKind.EXPENSE, "category-transportation", 31),
        sub("category-metro", "Metro", TransactionKind.EXPENSE, "category-transportation", 32),
        sub("category-fuel", "Fuel", TransactionKind.EXPENSE, "category-transportation", 33),
        sub("category-parking", "Parking", TransactionKind.EXPENSE, "category-transportation", 34),

        top("category-housing", "Housing", TransactionKind.EXPENSE, 40),
        sub("category-rent", "Rent", TransactionKind.EXPENSE, "category-housing", 41),
        sub("category-utilities", "Utilities", TransactionKind.EXPENSE, "category-housing", 42),
        sub("category-maintenance", "Maintenance", TransactionKind.EXPENSE, "category-housing", 43),
        sub("category-internet", "Internet", TransactionKind.EXPENSE, "category-housing", 44),

        top("category-shopping", "Shopping", TransactionKind.EXPENSE, 50),
        sub("category-clothing", "Clothing", TransactionKind.EXPENSE, "category-shopping", 51),
        sub("category-electronics", "Electronics", TransactionKind.EXPENSE, "category-shopping", 52),
        sub("category-household", "Household", TransactionKind.EXPENSE, "category-shopping", 53),
        sub("category-laundry", "Laundry", TransactionKind.EXPENSE, "category-shopping", 54),

        top("category-travel", "Travel", TransactionKind.EXPENSE, 60),
        sub("category-hotel", "Hotel", TransactionKind.EXPENSE, "category-travel", 61),
        sub("category-flights", "Flights", TransactionKind.EXPENSE, "category-travel", 62),
        sub("category-visa", "Visa", TransactionKind.EXPENSE, "category-travel", 63),
        sub("category-travel-transport", "Travel Transport", TransactionKind.EXPENSE, "category-travel", 64),

        top("category-health", "Health", TransactionKind.EXPENSE, 70),
        sub("category-pharmacy", "Pharmacy", TransactionKind.EXPENSE, "category-health", 71),
        sub("category-doctor", "Doctor", TransactionKind.EXPENSE, "category-health", 72),
        sub("category-insurance", "Insurance", TransactionKind.EXPENSE, "category-health", 73),
        sub("category-fitness", "Fitness", TransactionKind.EXPENSE, "category-health", 74),

        top("category-family", "Family", TransactionKind.EXPENSE, 80),
        sub("category-gifts", "Gifts", TransactionKind.EXPENSE, "category-family", 81),
        sub("category-education", "Education", TransactionKind.EXPENSE, "category-family", 82),
        sub("category-kids", "Kids", TransactionKind.EXPENSE, "category-family", 83),
        sub("category-support", "Support", TransactionKind.EXPENSE, "category-family", 84),

        top("category-entertainment", "Entertainment", TransactionKind.EXPENSE, 90),
        sub("category-movies", "Movies", TransactionKind.EXPENSE, "category-entertainment", 91),
        sub("category-subscriptions", "Subscriptions", TransactionKind.EXPENSE, "category-entertainment", 92),
        sub("category-events", "Events", TransactionKind.EXPENSE, "category-entertainment", 93),
        sub("category-games", "Games", TransactionKind.EXPENSE, "category-entertainment", 94),

        top("category-finance", "Finance", TransactionKind.EXPENSE, 100),
        sub("category-bank-fees", "Bank Fees", TransactionKind.EXPENSE, "category-finance", 101),
        sub("category-card-payment", "Card Payment", TransactionKind.EXPENSE, "category-finance", 102),
        sub("category-tax", "Tax", TransactionKind.EXPENSE, "category-finance", 103),

        top("category-savings", "Savings", TransactionKind.EXPENSE, 110),
        sub("category-emergency-fund", "Emergency Fund", TransactionKind.EXPENSE, "category-savings", 111),
        sub("category-investment", "Investment", TransactionKind.EXPENSE, "category-savings", 112),
        sub("category-debt-payment", "Debt Payment", TransactionKind.EXPENSE, "category-savings", 113),

        top("category-transfer", "Transfer", TransactionKind.TRANSFER, 120),
    )

    val ids: Set<String> = all.map { it.id.value }.toSet()
}
