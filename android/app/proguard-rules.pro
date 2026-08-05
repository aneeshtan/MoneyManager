# Room and Hilt provide consumer rules. Add project rules only when release verification proves they are required.

# pdfbox-android's JPXFilter references the optional gemalto JPEG2000 decoder,
# which is not bundled; JP2-encoded images are not required for text extraction.
-dontwarn com.gemalto.jp2.**
