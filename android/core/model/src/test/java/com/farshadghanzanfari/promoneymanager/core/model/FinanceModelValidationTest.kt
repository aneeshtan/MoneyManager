package com.farshadghanzanfari.promoneymanager.core.model

import com.google.common.truth.Truth.assertThat
import org.junit.Assert.assertThrows
import org.junit.Test

class FinanceModelValidationTest {
    @Test
    fun categoryRequiresName() {
        val error = assertThrows(IllegalArgumentException::class.java) {
            Category(
                id = CategoryId("category-food"),
                name = "   ",
                kind = TransactionKind.EXPENSE,
            )
        }

        assertThat(error).hasMessageThat().contains("name")
    }

    @Test
    fun categoryCannotBeItsOwnParent() {
        val error = assertThrows(IllegalArgumentException::class.java) {
            Category(
                id = CategoryId("category-food"),
                name = "Food",
                kind = TransactionKind.EXPENSE,
                parentId = CategoryId("category-food"),
            )
        }

        assertThat(error).hasMessageThat().contains("parent")
    }

    @Test
    fun categoryAllowsDistinctParent() {
        val category = Category(
            id = CategoryId("category-coffee"),
            name = "Coffee",
            kind = TransactionKind.EXPENSE,
            parentId = CategoryId("category-food"),
            sortOrder = 2,
            isArchived = true,
        )

        assertThat(category.parentId).isEqualTo(CategoryId("category-food"))
        assertThat(category.sortOrder).isEqualTo(2)
        assertThat(category.isArchived).isTrue()
    }

    @Test
    fun tagRequiresName() {
        val error = assertThrows(IllegalArgumentException::class.java) {
            Tag(id = TagId("tag-business"), name = "", colorHex = "8151D1")
        }

        assertThat(error).hasMessageThat().contains("name")
    }

    @Test
    fun tagRequiresSixCharacterHexColor() {
        assertThrows(IllegalArgumentException::class.java) {
            Tag(id = TagId("tag-business"), name = "Business", colorHex = "BAD")
        }

        assertThrows(IllegalArgumentException::class.java) {
            Tag(id = TagId("tag-business"), name = "Business", colorHex = "GGGGGG")
        }
    }

    @Test
    fun tagStoresUppercaseColor() {
        val tag = Tag(id = TagId("tag-business"), name = "Business", colorHex = "8151d1")

        assertThat(tag.colorHex).isEqualTo("8151D1")
    }
}
