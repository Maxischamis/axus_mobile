import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../models/product.dart';

class ApiService {
  final Map<String, List<Product>> _cache = {};

  final Map<String, dynamic> stores = {
    "COTO": {
      "id": "COTO",
      "name": "Coto Digital",
      "color": "#ef4444",
      "url_base": "https://www.cotodigital.com.ar"
    },
    "CARREFOUR": {
      "id": "CARREFOUR",
      "name": "Carrefour",
      "color": "#3b82f6",
      "url_base": "https://www.carrefour.com.ar"
    },
    "VEA": {
      "id": "VEA",
      "name": "Vea Cencosud",
      "color": "#22c55e",
      "url_base": "https://www.vea.com.ar"
    },
    "JUMBO": {
      "id": "JUMBO",
      "name": "Jumbo",
      "color": "#05c365",
      "url_base": "https://www.jumbo.com.ar"
    },
    "ATOMO": {
      "id": "ATOMO",
      "name": "Atomo Conviene",
      "color": "#e30613",
      "url_base": "https://atomoconviene.com"
    }
  };

  Map<String, String> _getHeaders(String host) {
    return {
      "User-Agent":
          "Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36",
      "Accept": "application/json, text/plain, */*",
      "Accept-Language": "es-419,es;q=0.9,en;q=0.8",
      "Origin": host,
      "Referer": "$host/",
      "X-Requested-With": "XMLHttpRequest",
    };
  }

  String _normalize(String text) {
    text = text.toLowerCase();
    text = text
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n');
    return text.trim();
  }

  String _cleanTitle(String s) {
    final noise = [
      RegExp(r"no acumulable.*", caseSensitive: false),
      RegExp(r"stock disponible", caseSensitive: false),
      RegExp(r"precio x unidad", caseSensitive: false),
      RegExp(r"precio por", caseSensitive: false),
      RegExp(r"disponible", caseSensitive: false),
      RegExp(r"artículo", caseSensitive: false),
      RegExp(r"producto", caseSensitive: false),
      RegExp(r"código", caseSensitive: false),
      RegExp(r"oferta", caseSensitive: false),
      RegExp(r"exclusivo digital", caseSensitive: false),
      RegExp(r"paquete", caseSensitive: false),
      RegExp(r"unid\.", caseSensitive: false),
      RegExp(r"llevando \d+", caseSensitive: false),
      RegExp(r"ahorra \d+", caseSensitive: false),
      RegExp(r"combinable", caseSensitive: false)
    ];
    for (var pattern in noise) {
      s = s.replaceAll(pattern, "");
    }
    s = s.trim();
    if (s.isEmpty) return "Producto";
    return s.split(' ').where((w) => w.isNotEmpty).map((word) {
      if (word.length < 2) return word.toUpperCase();
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Map<String, dynamic>? _extractUnitPrice(String name, double price) {
    final match = RegExp(r"(\d+[,.]?\d*)\s*(kg|g|l|cc|ml|gr|lt)")
        .firstMatch(name.toLowerCase());
    if (match != null) {
      try {
        double value = double.parse(match.group(1)!.replaceAll(',', '.'));
        String unit = match.group(2)!;
        if (["g", "gr", "ml", "cc"].contains(unit)) value = value / 1000;
        if (value > 0) {
          double rawUp = price / value;
          String displayUp = "\$${rawUp.toStringAsFixed(0)}/${[
            "l",
            "ml",
            "cc",
            "lt"
          ].contains(unit) ? 'L' : 'KG'}";
          return {"display": displayUp, "raw": rawUp};
        }
      } catch (_) {}
    }
    return null;
  }

  double _calculateRelevance(String name, String query) {
    String n = _normalize(name);
    String q = _normalize(query);
    if (q.isEmpty) return 0;
    double score = 0;
    List<String> qWords = q.split(' ').where((w) => w.length > 2).toList();
    if (qWords.isEmpty) qWords = q.split(' ');

    if (n.contains(q)) score += 5000;
    List<String> nWords = n.split(' ');
    for (int i = 0; i < qWords.length; i++) {
      if (nWords.contains(qWords[i])) {
        score += 1000;
        if (i == 0 && n.startsWith(qWords[i])) score += 500;
      } else if (n.contains(qWords[i])) {
        score += 300;
      }
    }
    return score / (1 + (nWords.length * 0.05));
  }

  Future<List<Product>> _searchVtex(
      String storeId, String query, int page) async {
    int from = (page - 1) * 40;
    int to = from + 39;
    String baseUrl = stores[storeId]['url_base'];
    final url = Uri.parse(
        "$baseUrl/api/catalog_system/pub/products/search?ft=${Uri.encodeComponent(query)}&_from=$from&_to=$to&O=OrderByPriceASC&map=ft&_=${DateTime.now().millisecondsSinceEpoch}");

    try {
      final r = await http
          .get(url, headers: _getHeaders(baseUrl))
          .timeout(const Duration(seconds: 12));
      // VTEX often returns 206 Partial Content when everything is fine
      if (r.statusCode != 200 && r.statusCode != 206) {
        debugPrint("VTEX $storeId returned status ${r.statusCode}");
        return [];
      }

      if (r.body.isEmpty || r.body == "[]") return [];

      List<dynamic> data = jsonDecode(r.body);
      List<Product> results = [];

      for (var p in data) {
        try {
          if (p["items"] == null || (p["items"] as List).isEmpty) continue;
          var item = p["items"][0];
          var sellers = item["sellers"] as List;
          if (sellers.isEmpty) continue;
          var offer = sellers[0]["commertialOffer"];

          double rawPrice = (offer["Price"] ?? 0).toDouble();
          double listPriceVal = (offer["ListPrice"] ?? 0).toDouble();

          if (rawPrice > 0 && (offer["AvailableQuantity"] ?? 0) > 0) {
            int discount = listPriceVal > rawPrice
                ? (((1 - rawPrice / listPriceVal) * 100).toInt())
                : 0;
            var unitData = _extractUnitPrice(p["productName"] ?? "", rawPrice);

            List<String> promos = [];
            if (p["clusterHighlights"] != null) {
              for (var v in (p["clusterHighlights"] as Map).values) {
                if (v is String && v.length < 25) promos.add(v.toUpperCase());
              }
            }

            results.add(Product(
              name: _cleanTitle(p["productName"] ?? ""),
              price: rawPrice.toStringAsFixed(2).replaceAll('.', ','),
              rawPrice: rawPrice,
              listPrice: discount > 0
                  ? listPriceVal.toStringAsFixed(2).replaceAll('.', ',')
                  : null,
              discount: discount,
              unitPrice: unitData?["display"],
              rawUnitPrice: (unitData?["raw"] ?? 999999).toDouble(),
              img: (item["images"] as List).isNotEmpty
                  ? item["images"][0]["imageUrl"]
                  : "",
              link: p["link"] ?? "",
              store: Store(
                  id: storeId,
                  name: stores[storeId]["name"],
                  logo: "",
                  color: stores[storeId]["color"]),
              promos: promos.take(2).toList(),
              relevance: _calculateRelevance(p["productName"] ?? "", query),
            ));
          }
        } catch (inner) {
          debugPrint("Error parsing VTEX product: $inner");
        }
      }
      return results;
    } catch (e) {
      debugPrint("VTEX Network Error $storeId: $e");
      return [];
    }
  }

  Future<List<Product>> _searchCoto(String query, int page) async {
    String baseUrl = "https://www.cotodigital.com.ar";
    final url = Uri.parse(
        "https://api.coto.com.ar/api/v1/ms-digital-sitio-bff-web/api/v1/products/search/${Uri.encodeComponent(query)}?key=key_r6xzz4IAoTWcipni&num_results_per_page=40&page=$page&sort=price_asc");

    try {
      final r = await http
          .get(url, headers: _getHeaders(baseUrl))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) {
        debugPrint("Coto returned status ${r.statusCode}");
        return [];
      }

      Map<String, dynamic> data = jsonDecode(r.body);
      List<dynamic> items = data["response"]?["results"] ?? [];
      List<Product> results = [];

      for (var it in items) {
        try {
          var d = it["data"];
          if (d == null) continue;

          double rawPrice = (d["product_list_price"] ?? 0).toDouble();
          double regPrice = (d["product_regular_price"] ?? 0).toDouble();

          if (rawPrice > 0) {
            int discount = regPrice > rawPrice
                ? (((1 - rawPrice / regPrice) * 100).toInt())
                : 0;
            var unitData =
                _extractUnitPrice(d["sku_display_name"] ?? "", rawPrice);

            List<String> promos = [];
            if (d["badges"] != null) {
              for (var b in (d["badges"] as List)) {
                if (b["text"] != null) {
                  promos.add(b["text"].toString().toUpperCase());
                }
              }
            }

            results.add(Product(
              name: _cleanTitle(d["sku_display_name"] ?? ""),
              price: rawPrice.toStringAsFixed(2).replaceAll('.', ','),
              rawPrice: rawPrice,
              listPrice: discount > 0
                  ? regPrice.toStringAsFixed(2).replaceAll('.', ',')
                  : null,
              discount: discount,
              unitPrice: unitData?["display"],
              rawUnitPrice: (unitData?["raw"] ?? 999999).toDouble(),
              img: d["product_large_image_url"] ?? "",
              link: "https://www.cotodigital.com.ar${d['url'] ?? ''}",
              store: Store(
                  id: "COTO", name: "Coto Digital", logo: "", color: "#ef4444"),
              promos: promos.take(2).toList(),
              relevance:
                  _calculateRelevance(d["sku_display_name"] ?? "", query),
            ));
          }
        } catch (inner) {
          debugPrint("Error parsing Coto product: $inner");
        }
      }
      return results;
    } catch (e) {
      debugPrint("Coto Network Error: $e");
      return [];
    }
  }

  Future<List<Product>> searchProducts(
    String query, {
    int page = 1,
    double? minPrice,
    double? maxPrice,
    String? sortBy,
    List<String>? stores,
  }) async {
    if (query.trim().isEmpty) return [];

    final cacheKey = '$query-$page-${stores?.join(',') ?? 'all'}';
    List<Product> products;

    if (_cache.containsKey(cacheKey)) {
      products = List.from(_cache[cacheKey]!);
    } else {
      List<Future<List<Product>>> tasks = [];
      bool all = stores == null || stores.isEmpty;

      if (all || stores.contains("COTO")) {
        tasks.add(_searchCoto(query, page));
      }
      if (all || stores.contains("CARREFOUR")) {
        tasks.add(_searchVtex("CARREFOUR", query, page));
      }
      if (all || stores.contains("VEA")) {
        tasks.add(_searchVtex("VEA", query, page));
      }
      if (all || stores.contains("JUMBO")) {
        tasks.add(_searchVtex("JUMBO", query, page));
      }
      if (all || stores.contains("ATOMO")) {
        tasks.add(_searchVtex("ATOMO", query, page));
      }

      final allResults = await Future.wait(tasks);
      products = allResults.expand((x) => x).toList();

      // Limit cache size
      if (_cache.length > 50) {
        _cache.clear();
      }
      _cache[cacheKey] = products;
    }

    return _applyLocalFilters(products, minPrice, maxPrice, sortBy, query);
  }

  List<Product> _applyLocalFilters(
    List<Product> products,
    double? minPrice,
    double? maxPrice,
    String? sortBy,
    String query,
  ) {
    var filtered = products.where((p) {
      if (minPrice != null && p.rawPrice < minPrice) return false;
      if (maxPrice != null && p.rawPrice > maxPrice) return false;
      return true;
    }).toList();

    if (sortBy == "price_asc") {
      filtered.sort((a, b) => a.rawPrice.compareTo(b.rawPrice));
    } else if (sortBy == "price_desc") {
      filtered.sort((a, b) => b.rawPrice.compareTo(a.rawPrice));
    } else {
      filtered.sort((a, b) {
        int rel = b.relevance.compareTo(a.relevance);
        if (rel == 0) return a.rawPrice.compareTo(b.rawPrice);
        return rel;
      });
    }

    return filtered;
  }

  Future<List<String>> getSuggestions(String query) async {
    final suggestions = [
      "Aceite",
      "Arroz",
      "Cerveza",
      "Coca Cola",
      "Leche",
      "Mayonesa",
      "Pan",
      "Papel Higienico",
      "Pure de Tomate",
      "Yerba",
      "Vino",
      "Jabón"
    ];
    String q = _normalize(query);
    if (q.isEmpty) return [];
    return suggestions.where((s) => _normalize(s).contains(q)).take(6).toList();
  }
}
