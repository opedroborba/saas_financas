import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:saas_shinko/models/conta_a_receber.dart';
import 'package:saas_shinko/models/categoria.dart'; // Para o filtro de categorias
import 'package:saas_shinko/screens/add_edit_receivable_screen.dart'; // Vamos criar esta tela
import 'package:saas_shinko/models/transacao.dart'; // Para criar a transação real

const Color primaryOrange = Color(0xFFF7A102);
const Color successGreen = Color(0xFF4CAF50);
const Color dangerRed = Color(0xFFD32F2F);
const Color pendingBlue = Color(0xFF2196F3); // Azul para pendente

final SupabaseClient supabase = Supabase.instance.client;

class AccountsReceivableScreen extends StatefulWidget {
  const AccountsReceivableScreen({Key? key}) : super(key: key);

  @override
  State<AccountsReceivableScreen> createState() =>
      _AccountsReceivableScreenState();
}

class _AccountsReceivableScreenState extends State<AccountsReceivableScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedCategoryFilterId;
  String? _selectedStatusFilter; // 'pendente', 'recebida', 'cancelada'

  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  late Future<List<ContaAReceber>> _contasAReceberFuture;
  List<Categoria> _categoriasDisponiveis = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Período inicial padrão para contas a receber (e.g., próximos 3 meses)
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
        _contasAReceberFuture = _fetchContasAReceber();
      });
    }
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });
    await _fetchCategories();
    _contasAReceberFuture = _fetchContasAReceber();
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

  Future<List<ContaAReceber>> _fetchContasAReceber() async {
    final User? currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      return [];
    }

    try {
      var query = supabase
          .from('contas_a_receber')
          .select('*, categorias(nome)')
          .eq('user_id', currentUser.id);

      if (_startDate != null) {
        query = query.gte('data_recebimento_prevista',
            DateFormat('yyyy-MM-dd').format(_startDate!));
      }
      if (_endDate != null) {
        query = query.lte('data_recebimento_prevista',
            DateFormat('yyyy-MM-dd').format(_endDate!));
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

      final List<dynamic> response = await query
          .order('data_recebimento_prevista', ascending: true)
          .limit(500);

      return response.map((json) => ContaAReceber.fromJson(json)).toList();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar contas a receber: $e')),
      );
      print('Erro ao carregar contas a receber: $e');
      return [];
    }
  }

  Future<void> _deleteContaAReceber(String id) async {
    final User? currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: const Text(
              'Tem certeza que deseja excluir esta conta a receber?'),
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
            .from('contas_a_receber')
            .delete()
            .eq('id', id)
            .eq('user_id', currentUser.id);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Conta a receber excluída com sucesso!')),
        );
        setState(() {
          _contasAReceberFuture = _fetchContasAReceber();
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir conta a receber: $e')),
        );
        print('Erro ao excluir conta a receber: $e');
      }
    }
  }

  Future<void> _markAsReceived(ContaAReceber conta) async {
    final User? currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    final bool? confirmReceive = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Marcar como Recebida?'),
          content: const Text(
              'Esta ação irá marcar a conta como recebida e criar uma transação de receita na sua lista de transações.'),
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

    if (confirmReceive == true) {
      try {
        // 1. Atualizar o status da conta a receber
        await supabase
            .from('contas_a_receber')
            .update({'status': 'recebida'})
            .eq('id', conta.id)
            .eq('user_id', currentUser.id);

        // 2. Criar uma nova transação de receita na tabela 'transacoes'
        final Transacao novaTransacao = Transacao(
          id: await _generateUniqueId(), // Função para gerar ID, se necessário
          userId: currentUser.id,
          descricao: 'Recebimento: ${conta.descricao}',
          valor: conta.valor,
          data: DateTime.now(), // Data do recebimento
          categoriaId: conta.categoriaId,
          tipo: 'receita', // Tipo fixo para recebimento
        );

        await supabase.from('transacoes').insert(novaTransacao.toJson());

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Conta marcada como recebida e transação adicionada!')),
        );
        setState(() {
          _contasAReceberFuture = _fetchContasAReceber(); // Recarrega as contas
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao marcar como recebida: $e')),
        );
        print('Erro ao marcar como recebida: $e');
      }
    }
  }

  // Helper para gerar um UUID. Idealmente, o banco faz isso automaticamente.
  Future<String> _generateUniqueId() async {
    // Isso é uma simplificação. Em produção, use UUIDs gerados pelo banco ou um pacote UUID robusto.
    // Ex: import 'package:uuid/uuid.dart'; var uuid = Uuid(); return uuid.v4();
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  Future<void> _selectDate(BuildContext context,
      {required bool isStartDate, required bool isRecebimento}) async {
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
        _contasAReceberFuture = _fetchContasAReceber();
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
        title: const Text('Contas a Receber'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading
                ? null
                : () {
                    setState(() {
                      _contasAReceberFuture = _fetchContasAReceber();
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
                      // Filtro de Data Início Recebimento
                      ElevatedButton.icon(
                        onPressed: () => _selectDate(context,
                            isStartDate: true, isRecebimento: true),
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          _startDate == null
                              ? 'Previsto De'
                              : 'Prev. De: ${formatDateTime.format(_startDate!)}',
                        ),
                      ),
                      // Filtro de Data Fim Recebimento
                      ElevatedButton.icon(
                        onPressed: () => _selectDate(context,
                            isStartDate: false, isRecebimento: true),
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          _endDate == null
                              ? 'Previsto Até'
                              : 'Prev. Até: ${formatDateTime.format(_endDate!)}',
                        ),
                      ),
                      // Filtro de Status
                      DropdownButton<String>(
                        hint: const Text('Status'),
                        value: _selectedStatusFilter,
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedStatusFilter = newValue;
                            _contasAReceberFuture = _fetchContasAReceber();
                          });
                        },
                        items: const [
                          DropdownMenuItem(
                              value: null, child: Text('Todos os Status')),
                          DropdownMenuItem(
                              value: 'pendente', child: Text('Pendente')),
                          DropdownMenuItem(
                              value: 'recebida', child: Text('Recebida')),
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
                            _contasAReceberFuture = _fetchContasAReceber();
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
                            hintText: 'Ex: Salário',
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
                                        _contasAReceberFuture =
                                            _fetchContasAReceber();
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
                    child: FutureBuilder<List<ContaAReceber>>(
                      future: _contasAReceberFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(
                              child: Text(
                                  'Erro ao carregar contas a receber: ${snapshot.error}'));
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return const Center(
                              child:
                                  Text('Nenhuma conta a receber encontrada.'));
                        } else {
                          return ListView.builder(
                            itemCount: snapshot.data!.length,
                            itemBuilder: (context, index) {
                              final conta = snapshot.data![index];
                              Color statusColor;
                              IconData statusIcon;
                              switch (conta.status) {
                                case 'recebida':
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
                                          'Previsão: ${formatDateTime.format(conta.dataRecebimentoPrevista)}'),
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
                                          color: successGreen,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (conta.status == 'pendente')
                                        IconButton(
                                          icon: const Icon(Icons.check,
                                              color: successGreen),
                                          onPressed: () =>
                                              _markAsReceived(conta),
                                          tooltip: 'Marcar como Recebida',
                                        ),
                                    ],
                                  ),
                                  onTap: () async {
                                    final bool? modified =
                                        await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            AddEditReceivableScreen(
                                          contaAReceber: conta,
                                        ),
                                      ),
                                    );
                                    if (modified == true) {
                                      setState(() {
                                        _contasAReceberFuture =
                                            _fetchContasAReceber();
                                      });
                                    }
                                  },
                                  onLongPress: () =>
                                      _deleteContaAReceber(conta.id),
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
                    builder: (context) => const AddEditReceivableScreen(),
                  ),
                );
                if (added == true) {
                  setState(() {
                    _contasAReceberFuture = _fetchContasAReceber();
                  });
                }
              },
        child: const Icon(Icons.add),
      ),
    );
  }
}
