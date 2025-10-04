import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const MeuApp());
}

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lista de Compras',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 2,
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 3,
          ),
        ),
        // ✅ Removido cardTheme daqui para evitar o erro
      ),
      home: const PaginaInicial(),
    );
  }
}

/// ====== MODELO COM CATEGORIA ======
enum Categoria { alimentos, bebidas, higiene, limpeza, outros }

extension CategoriaExt on Categoria {
  String get label {
    switch (this) {
      case Categoria.alimentos:
        return 'Alimentos';
      case Categoria.bebidas:
        return 'Bebidas';
      case Categoria.higiene:
        return 'Higiene';
      case Categoria.limpeza:
        return 'Limpeza';
      case Categoria.outros:
        return 'Outros';
    }
  }

  IconData get icon {
    switch (this) {
      case Categoria.alimentos:
        return Icons.restaurant;
      case Categoria.bebidas:
        return Icons.local_drink;
      case Categoria.higiene:
        return Icons.health_and_safety;
      case Categoria.limpeza:
        return Icons.cleaning_services;
      case Categoria.outros:
        return Icons.category;
    }
  }

  Color get color {
    switch (this) {
      case Categoria.alimentos:
        return Colors.green;
      case Categoria.bebidas:
        return Colors.blue;
      case Categoria.higiene:
        return Colors.purple;
      case Categoria.limpeza:
        return Colors.orange;
      case Categoria.outros:
        return Colors.grey;
    }
  }

  static Categoria fromString(String s) {
    return Categoria.values.firstWhere(
      (c) => c.name == s,
      orElse: () => Categoria.outros,
    );
  }
}

class ItemCompra {
  final String nome;
  final bool comprado;
  final Categoria categoria;

  ItemCompra({
    required this.nome,
    this.comprado = false,
    this.categoria = Categoria.outros,
  });

  ItemCompra copyWith({String? nome, bool? comprado, Categoria? categoria}) {
    return ItemCompra(
      nome: nome ?? this.nome,
      comprado: comprado ?? this.comprado,
      categoria: categoria ?? this.categoria,
    );
  }

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'comprado': comprado,
        'categoria': categoria.name,
      };

  factory ItemCompra.fromMap(Map<String, dynamic> map) {
    return ItemCompra(
      nome: map['nome'] as String,
      comprado: map['comprado'] as bool? ?? false,
      categoria: CategoriaExt.fromString(map['categoria'] as String? ?? 'outros'),
    );
  }
}

/// ====== PÁGINA PRINCIPAL ======
class PaginaInicial extends StatefulWidget {
  const PaginaInicial({super.key});

  @override
  State<PaginaInicial> createState() => _PaginaInicialState();
}

class _PaginaInicialState extends State<PaginaInicial> {
  final _prefsKey = 'itens_lista_compras_v1';

  // Estado base
  final List<ItemCompra> _itens = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  // Entrada de dados
  final TextEditingController _ctrlItem = TextEditingController();
  Categoria _categoriaSelecionada = Categoria.outros;

  // Busca e filtros
  final TextEditingController _ctrlBusca = TextEditingController();
  Categoria? _filtroCategoria; // null = todas
  String get _query => _ctrlBusca.text.trim().toLowerCase();

  List<ItemCompra> get _itensFiltrados {
    Iterable<ItemCompra> base = _itens;
    if (_filtroCategoria != null) {
      base = base.where((i) => i.categoria == _filtroCategoria);
    }
    if (_query.isNotEmpty) {
      base = base.where((i) => i.nome.toLowerCase().contains(_query));
    }
    return base.toList();
  }

  @override
  void initState() {
    super.initState();
    _carregarPersistido();
  }

  @override
  void dispose() {
    _ctrlItem.dispose();
    _ctrlBusca.dispose();
    super.dispose();
  }

  /// ====== PERSISTÊNCIA ======
  Future<void> _salvarPersistencia() async {
    final prefs = await SharedPreferences.getInstance();
    final listaMap = _itens.map((e) => e.toMap()).toList();
    await prefs.setString(_prefsKey, jsonEncode(listaMap));
  }

  Future<void> _carregarPersistido() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefsKey);
    if (jsonStr == null) return;

    final List<dynamic> data = jsonDecode(jsonStr);
    final carregados = data.map((e) => ItemCompra.fromMap(e)).toList();

    for (var i = 0; i < carregados.length; i++) {
      _itens.insert(i, carregados[i]);
    }
    setState(() {}); // atualiza contadores e filtros
  }

  /// ====== AÇÕES ======
  void _adicionarItem() {
    String nome = _ctrlItem.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (nome.isEmpty) return;

    final jaExiste = _itens.any((e) => e.nome.toLowerCase() == nome.toLowerCase());
    if (jaExiste) {
      _mostrarMsg('Este item já está na lista.');
      return;
    }

    final novo = ItemCompra(nome: nome, categoria: _categoriaSelecionada);
    final index = _itens.length;

    setState(() {
      _itens.add(novo);
      _ctrlItem.clear();
    });
    _listKey.currentState?.insertItem(index, duration: const Duration(milliseconds: 250));
    _salvarPersistencia();
    _mostrarMsg('Item "$nome" adicionado!');
  }

  void _removerItem(int indexNaListaFiltrada) {
    final item = _itensFiltrados[indexNaListaFiltrada];
    final indexReal = _itens.indexOf(item);
    if (indexReal < 0) return;

    final removido = _itens.removeAt(indexReal);
    _listKey.currentState?.removeItem(
      indexReal,
      (context, animation) => _construirItem(removido, indexNaListaFiltrada, animation),
      duration: const Duration(milliseconds: 250),
    );
    setState(() {});
    _salvarPersistencia();
    _mostrarMsg('Item "${removido.nome}" removido!');
  }

  void _alternarComprado(int indexNaListaFiltrada, bool comprado) {
    final item = _itensFiltrados[indexNaListaFiltrada];
    final indexReal = _itens.indexOf(item);
    if (indexReal < 0) return;

    setState(() {
      _itens[indexReal] = item.copyWith(comprado: comprado);
    });
    _salvarPersistencia();
  }

  void _limparLista() {
    if (_itens.isEmpty) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Limpar Lista'),
        content: const Text('Tem certeza que deseja remover todos os itens?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              for (int i = _itens.length - 1; i >= 0; i--) {
                final removido = _itens.removeAt(i);
                _listKey.currentState?.removeItem(
                  i,
                  (context, animation) => _construirItem(removido, i, animation),
                  duration: const Duration(milliseconds: 250),
                );
              }
              setState(() {});
              _salvarPersistencia();
              _mostrarMsg('Lista limpa!');
            },
            child: const Text('Limpar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _compartilharLista() {
    if (_itens.isEmpty) {
      _mostrarMsg('A lista está vazia para compartilhar.');
      return;
    }
    final linhas = <String>[
      '🛒 Minha Lista de Compras',
      ..._itens.map((i) => '- ${i.nome} [${i.categoria.label}] ${i.comprado ? "✔️" : ""}'),
    ];
    Share.share(linhas.join('\n'));
  }

  void _mostrarMsg(String s) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s), duration: const Duration(seconds: 2)),
    );
  }

  /// ====== UI ======
  @override
  Widget build(BuildContext context) {
    final total = _itens.length;
    final comprados = _itens.where((e) => e.comprado).length;
    final restantes = total - comprados;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha Lista de Compras'),
        actions: [
          IconButton(
            onPressed: _compartilharLista,
            tooltip: 'Compartilhar lista',
            icon: const Icon(Icons.share),
          ),
          IconButton(
            onPressed: _limparLista,
            tooltip: 'Limpar lista',
            icon: const Icon(Icons.clear_all),
          ),
        ],
      ),
      body: Column(
        children: [
          // ====== BUSCA + FILTRO CATEGORIA ======
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.25),
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrlBusca,
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Buscar item',
                      hintText: 'Digite para filtrar',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<Categoria?>(
                    value: _filtroCategoria,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<Categoria?>(
                        value: null,
                        child: Text('Todas as categorias'),
                      ),
                      ...Categoria.values.map(
                        (c) => DropdownMenuItem<Categoria?>(
                          value: c,
                          child: Text(c.label),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _filtroCategoria = v),
                    decoration: const InputDecoration(
                      labelText: 'Categoria',
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ====== ESTATÍSTICAS ======
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: total == 0
                ? const SizedBox(height: 8, key: ValueKey('vazio_stats'))
                : Padding(
                    key: const ValueKey('stats'),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _stat('Total', '$total', Icons.list, Colors.blue),
                        _stat('Comprados', '$comprados', Icons.check_circle, Colors.green),
                        _stat('Restantes', '$restantes', Icons.pending, Colors.orange),
                      ],
                    ),
                  ),
          ),

          // ====== ADIÇÃO (campo com uma linha só pra ele) ======
Container(
  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // 1) Campo de texto — linha inteira
      TextField(
        controller: _ctrlItem,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _adicionarItem(),
        maxLines: 1, // 🔹 uma linha
        style: const TextStyle(fontSize: 18),
        decoration: const InputDecoration(
          labelText: 'Novo item',
          hintText: 'Digite o item que deseja adicionar...',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          prefixIcon: Icon(Icons.add_shopping_cart),
        ),
      ),

      const SizedBox(height: 12),

      // 2) Segunda linha — categoria + botão
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<Categoria>(
              value: _categoriaSelecionada,
              isExpanded: true,
              items: Categoria.values
                  .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _categoriaSelecionada = v ?? Categoria.outros),
              decoration: const InputDecoration(
                labelText: 'Categoria',
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _adicionarItem,
            icon: const Icon(Icons.add),
            label: const Text(
              'Adicionar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ],
  ),
),

          

          // ====== LISTA ======
          Expanded(child: _construirLista()),
        ],
      ),
    );
  }

  // LISTA com AnimatedList + filtro aplicado visualmente
  Widget _construirLista() {
    final filtrados = _itensFiltrados;

    if (_itens.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text('Sua lista está vazia!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const Text('Adicione itens para começar', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return AnimatedList(
      key: _listKey,
      initialItemCount: _itens.length,
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      itemBuilder: (context, indexBase, animation) {
        if (indexBase < 0 || indexBase >= _itens.length) return const SizedBox.shrink();
        final itemBase = _itens[indexBase];
        final posFiltrada = filtrados.indexOf(itemBase);
        if (posFiltrada == -1) return const SizedBox.shrink();
        return _construirItem(itemBase, posFiltrada, animation);
      },
    );
  }

  Widget _construirItem(ItemCompra item, int indexFiltrado, Animation<double> animation) {
    final corFundo = item.comprado ? Colors.teal.withOpacity(0.06) : null;

    return SizeTransition(
      sizeFactor: animation,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // ✅ forma no card
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: corFundo,
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: CircleAvatar(
              backgroundColor: item.categoria.color.withOpacity(0.15),
              child: Icon(item.categoria.icon, color: item.categoria.color),
            ),
            title: Text(
              item.nome,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                decoration: item.comprado ? TextDecoration.lineThrough : null,
                color: item.comprado ? Colors.grey : Colors.black87,
              ),
            ),
            subtitle: Text(item.categoria.label),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: item.comprado,
                  onChanged: (v) => _alternarComprado(indexFiltrado, v ?? false),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  tooltip: 'Remover',
                  onPressed: () => _removerItem(indexFiltrado),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String titulo, String valor, IconData icone, Color cor) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          children: [
            Icon(icone, color: cor, size: 24),
            const SizedBox(height: 6),
            Text(valor, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cor)),
            Text(titulo, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
