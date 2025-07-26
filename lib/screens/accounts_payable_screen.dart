import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:saas_shinko/models/conta_a_pagar.dart';
import 'package:saas_shinko/models/categoria.dart'; // Para o filtro de categorias
import 'package:saas_shinko/screens/add_edit_payable_screen.dart'; // Vamos criar esta tela
import 'package:saas_shinko/models/transacao.dart'; // Para criar a transação real

const Color primaryOrange = Color(0xFFF7A102);
const Color successGreen = Color(0xFF4CAF50);
const Color dangerRed = Color(0xFFD32F2F);
const Color pendingBlue = Color(0xFF2196F3); // Azul para pendente

final SupabaseClient supabase = Supabase.instance.client;

class AccountsPayableScreen extends StatefulWidget {
  const AccountsPayableScreen({Key? key}) : super(key: key);

  @override
  State<AccountsPayableScreen> createState() => _AccountsPayableScreenState();
}

class _AccountsPayableScreenState extends State<AccountsPayableScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedCategoryFilterId;
  String? _selectedStatusFilter; // 'pendente', 'paga', 'cancelada'

  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  late Future<List<ContaAPagar>> _contasAPagarFuture;
  List<Categoria> _categoriasDisponiveis = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Período inicial padrão para contas a pagar (e.g., próximos 3 meses)
    _startDate = DateTime(now.year, now.month, 1);
    _endDate =
        DateTime(now.year, now.month + 3, 0); // Fim do mês 3 meses à frente

    _loadInitialData();
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
        _contasAPagarFuture = _fetchContasAPagar();
      });
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });
    await _fetchCategories();
    _contasAPagarFuture = _fetchContasAPagar();
    setState(() {
      _isLoading = false;
    });
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

  Future<List<ContaAPagar>> _fetchContasAPagar() async {
    final User? currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      return [];
    }

    try {
      var query = supabase
          .from('contas_a_pagar')
          .select('*, categorias(nome)')
          .eq('user_id', currentUser.id);

      if (_startDate != null) {
        query = query.gte(
            'data_vencimento', DateFormat('yyyy-MM-dd').format(_startDate!));
      }
      if (_endDate != null) {
        query = query.lte(
            'data_vencimento', DateFormat('yyyy-MM-dd').format(_endDate!));
      }

      if (_searchTerm.isNotEmpty) {
        query = query.ilike('descricao', '%$_searchTerm%');
      }

      if (_selectedCategoryFilterId != null) {
        query = query.eq('categoria_id', _selectedCategoryFilterId!);
      }
      if (_selectedStatusFilter != null) {
        query = query.eq('status', _selectedStatusFilter!);
      }

      final List<dynamic> response =
          await query.order('data_vencimento', ascending: true).limit(500);

      return response.map((json) => ContaAPagar.fromJson(json)).toList();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar contas a pagar: $e')),
      );
      print('Erro ao carregar contas a pagar: $e');
      return [];
    }
  }

  Future<void> _deleteContaAPagar(String id) async {
    final User? currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content:
              const Text('Tem certeza que deseja excluir esta conta a pagar?'),
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
            .from('contas_a_pagar')
            .delete()
            .eq('id', id)
            .eq('user_id', currentUser.id);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conta a pagar excluída com sucesso!')),
        );
        setState(() {
          _contasAPagarFuture = _fetchContasAPagar();
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir conta a pagar: $e')),
        );
        print('Erro ao excluir conta a pagar: $e');
      }
    }
  }

  Future<void> _markAsPaid(ContaAPagar conta) async {
    final User? currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    final bool? confirmPay = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Marcar como Paga?'),
          content: const Text(
              'Esta ação irá marcar a conta como paga e criar uma transação de despesa na sua lista de transações.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirmar',
                  style: TextStyle(color: Colors.green)),
            ),
          ],
        );
      },
    );

    if (confirmPay == true) {
      try {
        // 1. Atualizar o status da conta a pagar
        await supabase
            .from('contas_a_pagar')
            .update({'status': 'paga'})
            .eq('id', conta.id)
            .eq('user_id', currentUser.id);

        // 2. Criar uma nova transação de despesa na tabela 'transacoes'
        final Transacao novaTransacao = Transacao(
          id: await _generateUniqueId(), // Função para gerar ID, se necessário
          userId: currentUser.id,
          descricao: 'Pagamento: ${conta.descricao}',
          valor: conta.valor,
          data: DateTime.now(), // Data do pagamento
          categoriaId: conta.categoriaId,
          tipo: 'despesa', // Tipo fixo para pagamento
        );

        await supabase.from('transacoes').insert(novaTransacao.toJson());

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Conta marcada como paga e transação adicionada!')),
        );
        setState(() {
          _contasAPagarFuture = _fetchContasAPagar(); // Recarrega as contas
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao marcar como paga: $e')),
        );
        print('Erro ao marcar como paga: $e');
      }
    }
  }

  // Helper para gerar um UUID. Idealmente, o banco faz isso automaticamente.
  // Se o Supabase está gerando UUIDs automaticamente, esta função pode não ser necessária,
  // basta não incluir o 'id' no toJson() ao inserir.
  Future<String> _generateUniqueId() async {
    // Isso é uma simplificação. Em produção, use UUIDs gerados pelo banco ou um pacote UUID robusto.
    // Ex: import 'package:uuid/uuid.dart'; var uuid = Uuid(); return uuid.v4();
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  Future<void> _selectDate(BuildContext context,
      {required bool isStartDate, required bool isVencimento}) async {
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
        _contasAPagarFuture = _fetchContasAPagar();
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
        title: const Text('Contas a Pagar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading
                ? null
                : () {
                    setState(() {
                      _contasAPagarFuture = _fetchContasAPagar();
                    });
                  },
            tooltip: 'Recarregar Contas',
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
                      // Filtro de Data Início Vencimento
                      ElevatedButton.icon(
                        onPressed: () => _selectDate(context,
                            isStartDate: true, isVencimento: true),
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          _startDate == null
                              ? 'Vencimento De'
                              : 'Venc. De: ${formatDateTime.format(_startDate!)}',
                        ),
                      ),
                      // Filtro de Data Fim Vencimento
                      ElevatedButton.icon(
                        onPressed: () => _selectDate(context,
                            isStartDate: false, isVencimento: true),
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          _endDate == null
                              ? 'Vencimento Até'
                              : 'Venc. Até: ${formatDateTime.format(_endDate!)}',
                        ),
                      ),
                      // Filtro de Status
                      DropdownButton<String>(
                        hint: const Text('Status'),
                        value: _selectedStatusFilter,
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedStatusFilter = newValue;
                            _contasAPagarFuture = _fetchContasAPagar();
                          });
                        },
                        items: const [
                          DropdownMenuItem(
                              value: null, child: Text('Todos os Status')),
                          DropdownMenuItem(
                              value: 'pendente', child: Text('Pendente')),
                          DropdownMenuItem(value: 'paga', child: Text('Paga')),
                          DropdownMenuItem(
                              value: 'cancelada', child: Text('Cancelada')),
                        ],
                      ),
                      // Filtro de Categoria
                      DropdownButton<String>(
                        hint: const Text('Categoria'),
                        value: _selectedCategoryFilterId,
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedCategoryFilterId = newValue;
                            _contasAPagarFuture = _fetchContasAPagar();
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
                            hintText: 'Ex: Aluguel',
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
                                        _contasAPagarFuture =
                                            _fetchContasAPagar();
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
                    child: FutureBuilder<List<ContaAPagar>>(
                      future: _contasAPagarFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(
                              child: Text(
                                  'Erro ao carregar contas a pagar: ${snapshot.error}'));
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return const Center(
                              child: Text('Nenhuma conta a pagar encontrada.'));
                        } else {
                          return ListView.builder(
                            itemCount: snapshot.data!.length,
                            itemBuilder: (context, index) {
                              final conta = snapshot.data![index];
                              Color statusColor;
                              IconData statusIcon;
                              switch (conta.status) {
                                case 'paga':
                                  statusColor = successGreen;
                                  statusIcon = Icons.check_circle;
                                  break;
                                case 'cancelada':
                                  statusColor = dangerRed;
                                  statusIcon = Icons.cancel;
                                  break;
                                default: // pendente
                                  statusColor = pendingBlue;
                                  statusIcon = Icons.pending;
                                  break;
                              }

                              return Card(
                                margin:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                elevation: 2,
                                child: ListTile(
                                  leading: Icon(
                                    statusIcon,
                                    color: statusColor,
                                  ),
                                  title: Text(
                                    conta.descricao,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          'Categoria: ${conta.categoriaNome ?? 'N/A'}'),
                                      Text(
                                          'Vencimento: ${formatDateTime.format(conta.dataVencimento)}'),
                                      Text(
                                        'Status: ${conta.status.toUpperCase()}',
                                        style: TextStyle(color: statusColor),
                                      ),
                                    ],
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        formatCurrency.format(conta.valor),
                                        style: TextStyle(
                                          color: dangerRed,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (conta.status == 'pendente')
                                        IconButton(
                                          icon: const Icon(Icons.check,
                                              color: successGreen),
                                          onPressed: () => _markAsPaid(conta),
                                          tooltip: 'Marcar como Paga',
                                        ),
                                    ],
                                  ),
                                  onTap: () async {
                                    final bool? modified =
                                        await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            AddEditPayableScreen(
                                          contaAPagar: conta,
                                        ),
                                      ),
                                    );
                                    if (modified == true) {
                                      setState(() {
                                        _contasAPagarFuture =
                                            _fetchContasAPagar();
                                      });
                                    }
                                  },
                                  onLongPress: () =>
                                      _deleteContaAPagar(conta.id),
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
                final bool? added = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AddEditPayableScreen(),
                  ),
                );
                if (added == true) {
                  setState(() {
                    _contasAPagarFuture = _fetchContasAPagar();
                  });
                }
              },
        child: const Icon(Icons.add),
      ),
    );
  }
}
