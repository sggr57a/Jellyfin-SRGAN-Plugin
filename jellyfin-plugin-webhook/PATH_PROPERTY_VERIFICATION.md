# Path Property Verification

## Summary

The `item.Path` property used in `DataObjectHelpers.cs` is **CORRECT** and is the standard way to access the file path in Jellyfin's BaseItem class.

## Verification Details

### Source Code Analysis

From Jellyfin's `MediaBrowser.Controller/Entities/BaseItem.cs` (version 10.10.7):

```csharp
/// <summary>
/// Gets or sets the path.
/// </summary>
/// <value>The path.</value>
[JsonIgnore]
public virtual string Path { get; set; }
```

This property is defined at line 245 in the BaseItem class and is the standard property for accessing the file system path of media items.

### Current Implementation in DataObjectHelpers.cs

Lines 64-67:
```csharp
if (!string.IsNullOrEmpty(item.Path))
{
    dataObject["Path"] = item.Path;
}
```

This implementation is **correct** and follows best practices:
1. It checks if the Path is not null or empty before adding it to the data object
2. It uses the standard `BaseItem.Path` property
3. It exposes the path to webhook templates as `{{Path}}`

## .NET Version Update

Updated from .NET 8.0 to .NET 9.0 to match your installed version:

- **Project File**: `Jellyfin.Plugin.Webhook.csproj` - Already set to `net9.0`
- **PATCH_NOTES.md**: Updated to reflect .NET 9.0 compatibility

## Usage in Webhooks

The Path variable can be used in webhook templates like this:

```json
{
  "Path": "{{Path}}",
  "Name": "{{Name}}",
  "ItemType": "{{ItemType}}"
}
```

Example output:
```json
{
  "Path": "/mnt/media/movies/Sample.mkv",
  "Name": "Sample Movie",
  "ItemType": "Movie"
}
```

## Alternative Properties (Not Recommended)

While there are other path-related properties in BaseItem, they serve different purposes:

- `ContainingFolderPath` - Returns the directory containing the item
- `FileNameWithoutExtension` - Returns just the filename without extension
- `GetInternalMetadataPath()` - Returns the internal metadata storage path

**`item.Path` is the correct property for getting the full file path of the media item.**

## Conclusion

No changes are needed to DataObjectHelpers.cs. The current implementation using `item.Path` is correct and compatible with:
- Jellyfin 10.8+
- .NET 9.0
- Current Jellyfin API

The webhook plugin should work as expected with the Path variable exposed to templates.
