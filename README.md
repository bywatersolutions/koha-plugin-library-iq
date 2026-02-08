# Library IQ plugin for Koha

## Installation

1. Install the plugin through the Koha plugin system
2. Create an API key for a user with the `catalogue` permission
3. Provide LibraryIQ with your catalog URL and API key

## Configuration

### Title Template

The plugin allows you to customize how titles are constructed in the API responses using a template system. This is particularly useful if you want to include additional MARC fields in your title display.

#### Format

The title template uses MARC field and subfield codes in the format `FIELD$SUBFIELD`. Multiple fields can be combined by separating them with commas.

#### Examples

- `245$a` - Just the title (MARC 245 $a)
- `245$a, 245$b` - Title and subtitle (MARC 245 $a and $b)
- `245$a, 240$a` - Title and uniform title (MARC 245 $a and 240 $a)

#### Default Behavior

If no template is specified, the plugin will use the standard `biblio.title` field.

#### Setting the Template

1. Go to the Koha administration interface
2. Navigate to the plugins page
3. Click on the "Configure" link for the LibraryIQ plugin
4. Enter your desired title template in the format described above
5. Click "Save" to apply your changes

## API Usage

Once installed and configured, the plugin provides API endpoints that LibraryIQ can use to access your catalog data. The API key you created during installation will be required for authentication.

### Pagination

The API supports pagination using the `limit` and `offset` query parameters. For example:

- `limit=10` - Limits the number of records returned to 10
- `offset=20` - Skips the first 20 records
