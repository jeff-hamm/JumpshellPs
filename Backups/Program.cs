using System.Net.Http.Headers;
using System.Text.Json;
using System.Text.Json.Serialization;

using var stream = File.OpenRead("imagesizes");
var data = JsonSerializer.Deserialize<DirInfo>(stream);

//var filtered = FilterInfo(data);

using var writer = File.CreateText("filteredimagesizes.json");
writer.Write(
    JsonSerializer.Serialize(
        new ReadablePathInfo("", data!)
    , new JsonSerializerOptions { WriteIndented = true, DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingDefault}));


DirInfo FilterInfo(DirInfo d) =>
    new DirInfo(d.Size, d.Bytes, Filter(d.Children)); 

Dictionary<string, DirInfo>? Filter(Dictionary<string, DirInfo>? d) =>
    d?.Where(kvp => kvp.Value is { TotalItems: > 100, TotalBytes: > 1024 })
        .ToDictionary(kvp => kvp.Key, kvp => 
            new DirInfo(kvp.Value.Size, 
                !String.IsNullOrEmpty(kvp.Value.Bytes) && kvp.Value.Bytes != "0" ? kvp.Value.Bytes : null,
                kvp.Value.Children?.Count > 0 ? Filter(kvp.Value.Children) : null));

Dictionary<string, DirInfo>? FilterReadable(Dictionary<string, DirInfo>? d) =>
    d?.Where(kvp => kvp.Value is { TotalItems: > 100, TotalBytes: > 1024 })
        .ToDictionary(kvp => kvp.Key, kvp => 
            new DirInfo(kvp.Value.Size, 
                !String.IsNullOrEmpty(kvp.Value.Bytes) && kvp.Value.Bytes != "0" ? kvp.Value.Bytes : null,
                kvp.Value.Children?.Count > 0 ? Filter(kvp.Value.Children) : null));




public class ReadablePathInfo
{
    const int MinItems = 100;
    const int MinBytes = 1024;
    public ReadablePathInfo(IEnumerable<KeyValuePair<string, DirInfo>> children, string? filtered)
    {
        Filtered = filtered;
        Properties = new (children.Select(kvp => ToPair(kvp.Key, kvp.Value)).OrderBy(kvp => kvp.Key));
    } 
    public ReadablePathInfo(string Name, DirInfo info)
    {
        Properties = new([ToPair(Name, info)]);
    }
    public string? Filtered { get; set; }
    [JsonExtensionData]public OrderedDictionary<string,object?>? Properties { get; set; }

    static object? ToNode(long totalItems, Dictionary<string, DirInfo>? items)
    {
        if(items?.Any() != true) return totalItems;
        var filtered =
            items.Select(kvp =>  new { Filtered=ShouldFilter(kvp), kvp})
                .ToLookup(g => g.Filtered, g => g);
        string? smallItemDesc = null;
        if (filtered.Contains(true))
        {
            var smallSums = filtered[true].Aggregate((0L,0L), (acc, f) => (acc.Item1 + f.kvp.Value.TotalItems, acc.Item2 + f.kvp.Value.TotalBytes));
            if(smallSums.Item1 > 0 || smallSums.Item2>0)
                smallItemDesc = $"{smallSums.Item1} Items in Small Folders" + (smallSums.Item2 > 0 ? $" [{DirInfo.FormatBytes(smallSums.Item2)}]" : "");
        }

        if (filtered.Contains(false))
        {
            return new ReadablePathInfo(filtered[false].Select(f => f.kvp),smallItemDesc);
        }

        return smallItemDesc;

    }

    private static bool ShouldFilter(KeyValuePair<string,DirInfo> i)
    {
        return i.Value is { TotalItems: < MinItems, TotalBytes: < MinBytes };
    }

    static KeyValuePair<string, object?> ToPair(string Name, DirInfo info) =>
        new(ToName(Name, info),
            ToNode(info.TotalItems, info.Children));

    private static string ToName(string Name, DirInfo info)
    {
        var suffix = "";
        if (info.TotalItems > 0)
        {
            suffix += $"{info.TotalItems} Images";
        }
        if (info.TotalBytes > 0)
        {
            if(!string.IsNullOrEmpty(suffix)) suffix += ", ";
            suffix += info.Total;
        }
        if(!string.IsNullOrEmpty(suffix)) suffix = $" [{suffix}]";

        return $"/{Name}{suffix}";
    }
}


public record DirInfo(int Size, string? Bytes, Dictionary<string, DirInfo>? Children)
{
    [JsonIgnore]
    public long RealBytes => ParseBytes(Bytes);

    public long ChildItems => Children?.Sum(kvp => kvp.Value.TotalItems)??0;

    [JsonIgnore]
    public long TotalItems => Size + ChildItems;
    [JsonIgnore]
    public long TotalBytes => RealBytes + (Children?.Sum(kvp => kvp.Value.TotalBytes)??0);

    public string Total => FormatBytes(TotalBytes);
    public static int ParseBytes(string? bytes)
    {
        if (string.IsNullOrEmpty(bytes)) return 0;

        bytes = bytes.ToUpperInvariant();
        if (bytes.EndsWith("TB")) return (int)(double.Parse(bytes.Replace("TB", "")) * 1_000_000_000_000);
        if (bytes.EndsWith("GB")) return (int)(double.Parse(bytes.Replace("GB", "")) * 1_000_000_000);
        if (bytes.EndsWith("MB")) return (int)(double.Parse(bytes.Replace("MB", "")) * 1_000_000);
        if (bytes.EndsWith("KB")) return (int)(double.Parse(bytes.Replace("KB", "")) * 1_000);

        return int.Parse(bytes);
    }

    public static string FormatBytes(long bytes)
    {
        if (bytes >= 1_000_000_000_000)
            return $"{(bytes / 1_000_000_000_000.0):F2}TB";
        if (bytes >= 1_000_000_000)
            return $"{(bytes / 1_000_000_000.0):F2}GB";
        if (bytes >= 1_000_000)
            return $"{(bytes / 1_000_000.0):F2}MB";
        if (bytes >= 1_000)
            return $"{(bytes / 1_000.0):F2}KB";

        return $"{bytes}B";
    }
    
}

