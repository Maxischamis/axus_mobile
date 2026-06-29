import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'dart:ui';
import 'dart:async';
import '../models/product.dart';
import '../services/api_service.dart';
import '../widgets/product_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();

  late AnimationController _headerFadeController;
  late Animation<double> _headerFadeAnimation;
  late AnimationController _scanningController;

  Timer? _debounce;

  List<Product> _products = [];
  List<String> _suggestions = [];
  bool _isLoading = false;
  bool _isMoreLoading = false;
  bool _showBackToTop = false;
  int _currentPage = 1;
  String _currentQuery = '';

  double? _minPrice;
  double? _maxPrice;
  String _sortBy = 'relevance';
  final List<String> _selectedStores = [];

  final List<Map<String, String>> _allStores = [
    {'id': 'COTO', 'name': 'Coto'},
    {'id': 'CARREFOUR', 'name': 'Carrefour'},
    {'id': 'VEA', 'name': 'Vea'},
    {'id': 'JUMBO', 'name': 'Jumbo'},
    {'id': 'ATOMO', 'name': 'Atomo'},
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    _headerFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _headerFadeAnimation = CurvedAnimation(
      parent: _headerFadeController,
      curve: Curves.easeOut,
    );
    _headerFadeController.forward();

    _scanningController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scanningController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _headerFadeController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.offset > 800 && !_showBackToTop) {
      setState(() => _showBackToTop = true);
    } else if (_scrollController.offset <= 800 && _showBackToTop) {
      setState(() => _showBackToTop = false);
    }

    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 500 &&
        !_isMoreLoading &&
        _products.isNotEmpty) {
      _loadMore();
    }
  }

  bool _hasActiveFilters() {
    return _minPrice != null ||
        _maxPrice != null ||
        _sortBy != 'relevance' ||
        _selectedStores.isNotEmpty;
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) return;
    HapticFeedback.lightImpact();
    _searchController.text = query;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _products = [];
      _currentPage = 1;
      _currentQuery = query;
      _suggestions = [];
    });

    try {
      final results = await _apiService.searchProducts(
        query,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        sortBy: _sortBy,
        stores: _selectedStores,
      );
      if (!mounted) return;
      setState(() {
        _products = results;
      });
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Intel Failure: Verificá tu conexión');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(message, style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Future<void> _loadMore() async {
    setState(() => _isMoreLoading = true);
    _currentPage++;

    try {
      final results = await _apiService.searchProducts(
        _currentQuery,
        page: _currentPage,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        sortBy: _sortBy,
        stores: _selectedStores,
      );
      if (mounted && results.isNotEmpty) {
        setState(() {
          _products.addAll(results);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isMoreLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030303),
      floatingActionButton: _showBackToTop ? _buildBackToTopButton() : null,
      body: Stack(
        children: [
          _buildBackgroundAura(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                FadeTransition(
                    opacity: _headerFadeAnimation,
                    child: _buildFuturisticHeader()),
                _buildModernSearchBar(),
                Expanded(
                  child: Stack(
                    children: [
                      RefreshIndicator(
                        onRefresh: () => _search(_currentQuery),
                        color: const Color(0xFFD4AF37),
                        backgroundColor: const Color(0xFF0D0D0F),
                        child: _isLoading
                            ? _buildScanningGridLoader()
                            : _buildProductGrid(),
                      ),
                      if (_suggestions.isNotEmpty)
                        _buildSuggestionsGlassOverlay(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundAura() {
    return Stack(
      children: [
        Positioned(
          top: -150,
          right: -100,
          child:
              _blurSphere(500, const Color(0xFFD4AF37).withValues(alpha: 0.08)),
        ),
        Positioned(
          bottom: -50,
          left: -150,
          child:
              _blurSphere(400, const Color(0xFF3b82f6).withValues(alpha: 0.04)),
        ),
      ],
    );
  }

  Widget _blurSphere(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 130, sigmaY: 130),
          child: Container(color: Colors.transparent)),
    );
  }

  Widget _buildFuturisticHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 15, 26, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AXUS',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFD4AF37),
                  letterSpacing: -4,
                  height: 0.8,
                ),
              ),
              Text(
                'ADVANCED INTEL SYSTEM',
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: Colors.white24,
                    letterSpacing: 6),
              ),
            ],
          ),
          _buildFilterControl(),
        ],
      ),
    );
  }

  Widget _buildFilterControl() {
    return InkWell(
      onTap: _showFilterSheet,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.tune_rounded, color: Color(0xFFD4AF37), size: 26),
            if (_hasActiveFilters())
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFF0D0D0F), width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      height: 75,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0F),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: const [
          BoxShadow(color: Colors.black, blurRadius: 25, offset: Offset(0, 8))
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.radar_rounded, color: Color(0xFFD4AF37), size: 26),
          const SizedBox(width: 18),
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'Infiltrar activos...',
                hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.1), fontSize: 16),
                border: InputBorder.none,
              ),
              onChanged: (val) {
                if (_debounce?.isActive ?? false) _debounce!.cancel();
                _debounce = Timer(const Duration(milliseconds: 500), () async {
                  if (val.length > 1) {
                    final suggs = await _apiService.getSuggestions(val);
                    if (mounted) setState(() => _suggestions = suggs);
                  } else {
                    if (mounted) setState(() => _suggestions = []);
                  }
                });
              },
              onSubmitted: _search,
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white24, size: 22),
              onPressed: () {
                HapticFeedback.lightImpact();
                _searchController.clear();
                setState(() => _suggestions = []);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildScanningGridLoader() {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 4,
      itemBuilder: (context, index) => AnimatedBuilder(
        animation: _scanningController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0F),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(22)),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                  height: 12, width: 80, color: Colors.white10),
                              const SizedBox(height: 8),
                              Container(
                                  height: 20,
                                  width: double.infinity,
                                  color: Colors.white10)
                            ]),
                      )
                    ],
                  ),
                  Positioned(
                    top: _scanningController.value * 300 - 50,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            const Color(0xFFD4AF37).withValues(alpha: 0.1),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductGrid() {
    if (_products.isEmpty && !_isLoading) {
      if (_currentQuery.isEmpty) return const SizedBox.shrink();
      return _buildEmptyState();
    }
    return AnimationLimiter(
      child: GridView.builder(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 15, 24, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _products.length + (_isMoreLoading ? 2 : 0),
        itemBuilder: (context, index) {
          if (index >= _products.length) {
            return const Center(
                child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                        color: Color(0xFFD4AF37), strokeWidth: 1.5)));
          }
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 1000),
            columnCount: 2,
            child: ScaleAnimation(
              scale: 0.9,
              curve: Curves.easeOutQuart,
              child: FadeInAnimation(
                child: ProductCard(product: _products[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuggestionsGlassOverlay() {
    return Positioned(
      top: 0,
      left: 24,
      right: 24,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0F).withValues(alpha: 0.96),
              border: Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _suggestions
                    .map((s) => ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 4),
                          title: Text(s,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16)),
                          trailing: const Icon(Icons.north_east_rounded,
                              color: Color(0xFFD4AF37), size: 20),
                          onTap: () => _search(s),
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackToTopButton() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
              blurRadius: 25)
        ],
      ),
      child: FloatingActionButton(
        mini: true,
        onPressed: () => _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutExpo),
        backgroundColor: const Color(0xFFD4AF37),
        child: const Icon(Icons.keyboard_arrow_up_rounded,
            color: Colors.black, size: 30),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Center(
        child: Column(
          children: [
            const SizedBox(height: 80),
            _pulsingRadar(),
            const SizedBox(height: 40),
            const Text('INTEL VACÍA',
                style: TextStyle(
                    color: Colors.white,
                    letterSpacing: 8,
                    fontWeight: FontWeight.w900,
                    fontSize: 14)),
            const SizedBox(height: 15),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 50),
              child: Text('Intentá con otros términos o filtros',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white12,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pulsingRadar() {
    return AnimatedBuilder(
      animation: _scanningController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(60),
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0D0D0F),
              border: Border.all(
                color: const Color(0xFFD4AF37).withValues(
                    alpha: 0.05 + (_scanningController.value * 0.15)),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4AF37)
                      .withValues(alpha: 0.05 * _scanningController.value),
                  blurRadius: 40 * _scanningController.value,
                  spreadRadius: 5 * _scanningController.value,
                )
              ]),
          child: const Icon(Icons.security_rounded,
              size: 80, color: Color(0xFFD4AF37)),
        );
      },
    );
  }

  void _showFilterSheet() {
    HapticFeedback.selectionClick();
    _minPriceController.text = _minPrice?.toString() ?? '';
    _maxPriceController.text = _maxPrice?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(builder: (context, setModalState) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D0D0F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
          ),
          padding: EdgeInsets.fromLTRB(
              26, 20, 26, MediaQuery.of(context).viewInsets.bottom + 35),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 45,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 35),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'PARÁMETROS',
                      style: TextStyle(
                          color: Color(0xFFD4AF37),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3),
                    ),
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          _minPrice = null;
                          _maxPrice = null;
                          _sortBy = 'relevance';
                          _selectedStores.clear();
                          _minPriceController.clear();
                          _maxPriceController.clear();
                        });
                      },
                      child: const Text('BORRAR',
                          style: TextStyle(
                              color: Colors.white24,
                              fontWeight: FontWeight.w900,
                              fontSize: 11)),
                    )
                  ],
                ),
                const SizedBox(height: 35),
                _buildSectionTitle('SISTEMA DE ORDENAMIENTO'),
                const SizedBox(height: 18),
                _buildSortOptions(setModalState),
                const SizedBox(height: 35),
                _buildSectionTitle('RANGO DE CRÉDITO (ARS)'),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                        child: _priceField(
                            'MÍN',
                            (v) => _minPrice = double.tryParse(v),
                            _minPriceController)),
                    const SizedBox(width: 15),
                    Expanded(
                        child: _priceField(
                            'MÁX',
                            (v) => _maxPrice = double.tryParse(v),
                            _maxPriceController)),
                  ],
                ),
                const SizedBox(height: 35),
                _buildSectionTitle('FUENTES DE DATOS'),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _allStores.map((store) {
                    final isSel = _selectedStores.contains(store['id']);
                    return InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setModalState(() {
                          if (isSel) {
                            _selectedStores.remove(store['id']!);
                          } else {
                            _selectedStores.add(store['id']!);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSel
                              ? const Color(0xFFD4AF37)
                              : const Color(0xFF161618),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          store['name']!.toUpperCase(),
                          style: TextStyle(
                            color: isSel ? Colors.black : Colors.white60,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 45),
                _buildApplyButton(),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
          color: Colors.white24,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 2),
    );
  }

  Widget _buildSortOptions(StateSetter setModalState) {
    final options = [
      {
        'id': 'relevance',
        'label': 'SISTEMA',
        'icon': Icons.auto_awesome_rounded
      },
      {
        'id': 'price_asc',
        'label': 'MIN PRECIO',
        'icon': Icons.trending_down_rounded
      },
      {
        'id': 'price_desc',
        'label': 'MAX PRECIO',
        'icon': Icons.trending_up_rounded
      },
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((opt) {
        final isSel = _sortBy == opt['id'];
        return InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setModalState(() => _sortBy = opt['id'] as String);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSel ? const Color(0xFFD4AF37) : const Color(0xFF161618),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(opt['icon'] as IconData,
                    size: 14, color: isSel ? Colors.black : Colors.white24),
                const SizedBox(width: 10),
                Text(opt['label'] as String,
                    style: TextStyle(
                        color: isSel ? Colors.black : Colors.white60,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 0.5)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _priceField(String hint, Function(String) onChange,
      TextEditingController controller) {
    return TextField(
      keyboardType: TextInputType.number,
      controller: controller,
      style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white10, fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF161618),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.all(22),
        prefixIcon: const Icon(Icons.credit_card_rounded,
            color: Colors.white10, size: 18),
      ),
      onChanged: onChange,
    );
  }

  Widget _buildApplyButton() {
    return Container(
      width: double.infinity,
      height: 75,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
            blurRadius: 35,
            offset: const Offset(0, 15),
          )
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD4AF37),
          foregroundColor: Colors.black,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          elevation: 0,
        ),
        onPressed: () {
          HapticFeedback.heavyImpact();
          Navigator.pop(context);
          _search(_currentQuery);
        },
        child: const Text('REINICIAR SISTEMA',
            style: TextStyle(
                fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: 3)),
      ),
    );
  }
}
