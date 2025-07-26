import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:saas_shinko/models/transacao.dart';
import 'package:saas_shinko/screens/add_transaction_screen.dart';
import 'package:saas_shinko/models/categoria.dart';

// Importante: Defina as cores aqui também, ou importe-as de um arquivo de constantes
// para evitar repetição e garantir consistência.
// Por simplicidade para este exemplo, vou duplicar as cores.
const Color primaryOrange = Color(0xFFF7A102);
const Color successGreen = Color(0xFF4CAF50);
const Color dangerRed = Color(0xFFD32F2F);

final SupabaseClient supabase = Supabase.instance.client;

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({Key? key}) : super(key: key);

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedCategoryFilterId;
  String? _selectedTypeFilter;

  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  late Future<List<Map<String, dynamic>>> _transacoesFuture;
  List<Categoria> _categoriasDisponiveis = [];

  bool _isLoading =
      false; // Pode ser útil se houver operações pesadas nesta tela

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Período inicial padrão para a tela de transações
    _startDate = DateTime(now.year, 1, 1);
    _endDate = DateTime(now.year, 12, 31, 23, 59, 59, 999);

    _loadInitialData(); // Carrega categorias e transações
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchTerm != _searchController.text.trim()) {
      setState(() {
        _searchTerm = _searchController.text.trim();
        _transacoesFuture = _fetchTransactions();
      });
    }
  }

  Future<void> _loadInitialData() async {
    await _fetchCategories();
    _transacoesFuture = _fetchTransactions();
    setState(() {}); // Força a reconstrução
  }

  Future<void> _fetchCategories() async {
    try {
      final User? currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        throw 'Usuário não autenticado!';
      }

      final List<dynamic> response = await supabase
          .from('categorias')
          .select()
          .eq('user_id', currentUser.id)
          .order('nome', ascending: true);

      setState(() {
        _categoriasDisponiveis =
            response.map((json) => Categoria.fromJson(json)).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar categorias para filtro: $e')),
      );
      print('Erro ao carregar categorias para filtro: $e');
      setState(() {
        _categoriasDisponiveis = [];
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchTransactions() async {
    final User? currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      return [];
    }

    try {
      var query = supabase
          .from('transacoes')
          .select('*, categorias(nome)')
          .eq('user_id', currentUser.id);

      if (_startDate != null) {
        query = query.gte('data', DateFormat('yyyy-MM-dd').format(_startDate!));
      }
      if (_endDate != null) {
        query = query.lte('data', DateFormat('yyyy-MM-dd').format(_endDate!));
      }

      if (_searchTerm.isNotEmpty) {
        query = query.ilike('descricao', '%$_searchTerm%');
      }

      // Aplicar filtros de tipo e categoria diretamente na query, se possível,
      // para reduzir dados recebidos e processamento local.
      // CORREÇÃO: Adicionar verificação de nulo antes de aplicar o filtro .eq()
      if (_selectedTypeFilter != null) {
        query = query.eq('tipo',
            _selectedTypeFilter!); // Adicionar ! para garantir que não é nulo
      }
      if (_selectedCategoryFilterId != null) {
        query =
            query.eq('categoria_id', _selectedCategoryFilterId!); // Adicionar !
      }

      final List<dynamic> response =
          await query.order('data', ascending: false).limit(500);

      // Não é mais necessário calcular totais e dados de gráficos aqui,
      // pois esta tela é apenas para a lista de transações.
      // Esses cálculos permanecem na HomeScreen.

      return response.map((jsonItem) {
        // Adaptar o item para incluir o nome da categoria para exibição
        Map<String, dynamic> itemWithCategory =
            Map<String, dynamic>.from(jsonItem);
        if (jsonItem['categorias'] != null &&
            jsonItem['categorias']['nome'] != null) {
          itemWithCategory['categoria_nome'] = jsonItem['categorias']['nome'];
        } else {
          itemWithCategory['categoria_nome'] = 'Sem Categoria';
        }
        return itemWithCategory;
      }).toList();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar transações: $e')),
      );
      print('Erro ao carregar transações: $e');
      return [];
    }
  }

  Future<void> _deleteTransaction(String transacaoId) async {
    final User? currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Erro: Usuário não autenticado para deletar.')),
      );
      return;
    }

    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: const Text('Tem certeza que deseja excluir esta transação?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Excluir', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        await supabase
            .from('transacoes')
            .delete()
            .eq('id', transacaoId)
            .eq('user_id', currentUser.id);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transação excluída com sucesso!')),
        );
        setState(() {
          _transacoesFuture = _fetchTransactions(); // Recarrega as transações
        });
        // Notifica a tela anterior (HomeScreen) que houve uma modificação
        // Se a HomeScreen precisar recarregar após uma exclusão aqui, esta linha é importante.
        // O `Navigator.pop(true)` serve para retornar um valor à tela que chamou esta.
        if (Navigator.of(context).canPop()) {
          // Verifica se pode dar pop antes de tentar
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir transação: $e')),
        );
        print('Erro ao excluir transação: $e');
        setState(() {
          _transacoesFuture = _fetchTransactions(); // Recarrega mesmo com erro
        });
      }
    } else {
      setState(() {
        _transacoesFuture = _fetchTransactions();
      });
    }
  }

  Future<void> _selectDate(BuildContext context,
      {required bool isStartDate}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
        _transacoesFuture = _fetchTransactions();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatCurrency =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final formatDateTime = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Transações'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading
                ? null
                : () {
                    setState(() {
                      _transacoesFuture = _fetchTransactions();
                    });
                  },
            tooltip: 'Recarregar Transações',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filtros
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      // Filtro de Data Início
                      ElevatedButton.icon(
                        onPressed: () =>
                            _selectDate(context, isStartDate: true),
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          _startDate == null
                              ? 'Data Início'
                              : 'De: ${formatDateTime.format(_startDate!)}',
                        ),
                      ),
                      // Filtro de Data Fim
                      ElevatedButton.icon(
                        onPressed: () =>
                            _selectDate(context, isStartDate: false),
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          _endDate == null
                              ? 'Data Fim'
                              : 'Até: ${formatDateTime.format(_endDate!)}',
                        ),
                      ),
                      // Filtro de Tipo (Receita/Despesa)
                      DropdownButton<String>(
                        hint: const Text('Tipo'),
                        value: _selectedTypeFilter,
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedTypeFilter = newValue;
                            _transacoesFuture = _fetchTransactions();
                          });
                        },
                        items: const [
                          DropdownMenuItem(
                              value: null, child: Text('Todos os Tipos')),
                          DropdownMenuItem(
                              value: 'receita', child: Text('Receita')),
                          DropdownMenuItem(
                              value: 'despesa', child: Text('Despesa')),
                        ],
                      ),
                      // Filtro de Categoria
                      DropdownButton<String>(
                        hint: const Text('Categoria'),
                        value: _selectedCategoryFilterId,
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedCategoryFilterId = newValue;
                            _transacoesFuture = _fetchTransactions();
                          });
                        },
                        items: [
                          const DropdownMenuItem<String>(
                              value: null, child: Text('Todas as Categorias')),
                          ..._categoriasDisponiveis.map(
                              (Categoria categoria) => DropdownMenuItem<String>(
                                    value: categoria.id,
                                    child: Text(categoria.nome),
                                  )),
                        ],
                      ),
                      // Campo de Busca
                      SizedBox(
                        width: 200,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'Buscar por descrição',
                            hintText: 'Ex: Aluguel, Salário',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchTerm = '';
                                        _transacoesFuture =
                                            _fetchTransactions();
                                      });
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    // Usar Expanded para a lista ocupar o espaço restante
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _transacoesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(
                              child: Text(
                                  'Erro ao carregar transações: ${snapshot.error}'));
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return const Center(
                              child: Text('Nenhuma transação encontrada.'));
                        } else {
                          return ListView.builder(
                            itemCount: snapshot.data!.length,
                            itemBuilder: (context, index) {
                              final transacaoMap = snapshot.data![index];
                              final transacao =
                                  Transacao.fromJson(transacaoMap);
                              final categoriaNome =
                                  transacaoMap['categorias'] != null
                                      ? transacaoMap['categorias']['nome']
                                      : 'Sem Categoria';

                              return Card(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                elevation: 2,
                                child: ListTile(
                                  leading: Icon(
                                    transacao.tipo == 'receita'
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                    color: transacao.tipo == 'receita'
                                        ? successGreen
                                        : dangerRed,
                                  ),
                                  title: Text(
                                    transacao.descricao,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Categoria: $categoriaNome'),
                                      Text(
                                          'Data: ${formatDateTime.format(transacao.data)}'),
                                    ],
                                  ),
                                  trailing: Text(
                                    formatCurrency.format(transacao.valor),
                                    style: TextStyle(
                                      color: transacao.tipo == 'receita'
                                          ? successGreen
                                          : dangerRed,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onTap: () async {
                                    final bool? transactionModified =
                                        await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            AddTransactionScreen(
                                          transacao: transacao,
                                        ),
                                      ),
                                    );
                                    if (transactionModified == true) {
                                      setState(() {
                                        _transacoesFuture =
                                            _fetchTransactions();
                                      });
                                      // Notifica a tela anterior (HomeScreen) que houve uma modificação
                                      if (Navigator.of(context).canPop()) {
                                        // Verifica se pode dar pop antes de tentar
                                        Navigator.of(context).pop(true);
                                      }
                                    }
                                  },
                                  onLongPress: () =>
                                      _deleteTransaction(transacao.id),
                                ),
                              );
                            },
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading
            ? null
            : () async {
                final bool? transactionAdded = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AddTransactionScreen(),
                  ),
                );
                if (transactionAdded == true) {
                  setState(() {
                    _transacoesFuture = _fetchTransactions();
                  });
                  // Notifica a tela anterior (HomeScreen) que houve uma adição
                  if (Navigator.of(context).canPop()) {
                    // Verifica se pode dar pop antes de tentar
                    Navigator.of(context).pop(true);
                  }
                }
              },
        child: const Icon(Icons.add),
      ),
    );
  }
}
