// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart'; // Importe fl_chart
import 'package:intl/intl.dart';

// Importe as telas
import 'package:saas_shinko/screens/transactions_screen.dart';
import 'package:saas_shinko/screens/accounts_payable_screen.dart';
import 'package:saas_shinko/screens/accounts_receivable_screen.dart';
import 'package:saas_shinko/screens/add_transaction_screen.dart'; // Para o FloatingActionButton
import 'package:saas_shinko/screens/cash_flow_screen.dart'; // Nova tela de fluxo de caixa

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  int _selectedIndex = 0; // Índice da tela atual (0 para Dashboard)

  String? _userEmail;
  double _balance = 0.0;
  Map<String, double> _categoryExpenses = {}; // Despesas por categoria
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchDashboardData();
  }

  Future<void> _fetchUserData() async {
    final User? user = supabase.auth.currentUser;
    if (user != null) {
      setState(() {
        _userEmail = user.email;
      });
    }
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
      _categoryExpenses = {}; // Limpa dados anteriores
    });
    try {
      final User? currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        throw 'Usuário não autenticado!';
      }

      // Buscar saldo total (simplificado: soma todas as transações)
      // Em um cenário real, você teria um saldo em conta.
      final List<dynamic> transactionsResponse = await supabase
          .from('transacoes')
          .select('valor, tipo')
          .eq('user_id', currentUser.id);

      double totalBalance = 0.0;
      for (var transaction in transactionsResponse) {
        if (transaction['tipo'] == 'receita') {
          totalBalance += (transaction['valor'] as num).toDouble();
        } else {
          totalBalance -= (transaction['valor'] as num).toDouble();
        }
      }

      // Buscar despesas por categoria no último mês
      final DateTime now = DateTime.now();
      final DateTime lastMonth = DateTime(now.year, now.month - 1, now.day);
      final String formattedLastMonth =
          DateFormat('yyyy-MM-dd').format(lastMonth);
      final String formattedNow = DateFormat('yyyy-MM-dd').format(now);

      final List<dynamic> expensesResponse = await supabase
          .from('transacoes')
          .select(
              'valor, categoria:categorias(nome)') // Puxa o nome da categoria
          .eq('user_id', currentUser.id)
          .eq('tipo', 'despesa')
          .gte('data', formattedLastMonth)
          .lte('data', formattedNow);

      for (var expense in expensesResponse) {
        final double value = (expense['valor'] as num).toDouble();
        // A categoria pode ser nula se não houver um ID de categoria na transação
        // ou se a categoria foi excluída depois. Usar um fallback.
        final String categoryName = expense['categoria']?['nome'] ?? 'Outros';
        _categoryExpenses.update(
            categoryName, (existingValue) => existingValue + value,
            ifAbsent: () => value);
      }

      setState(() {
        _balance = totalBalance;
      });

      // --- CORREÇÃO AQUI ---
      // Calcular totalExpenses dentro deste escopo para o print
      final double currentTotalExpenses =
          _categoryExpenses.values.fold(0.0, (sum, item) => sum + item);

      print('--- Dashboard Data Fetched ---');
      print('Balance: $_balance');
      print('Category Expenses: $_categoryExpenses');
      print(
          'Total Expenses for Pie Chart: $currentTotalExpenses'); // Usando a variável definida aqui
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar dados do dashboard: $e')),
      );
      print(
          'Erro ao carregar dados do dashboard: $e'); // Print do erro para console
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await supabase.auth.signOut();
      Navigator.of(context)
          .pushReplacementNamed('/login'); // Redireciona para a tela de login
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao sair: $e')),
      );
    }
  }

  // Conteúdo da Dashboard (simplificado)
  Widget _buildDashboardContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final double totalExpenses =
        _categoryExpenses.values.fold(0.0, (sum, item) => sum + item);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Saldo Atual',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'R\$ ${_balance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _balance >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Despesas por Categoria (Últimos 30 dias)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          // MODIFICAÇÃO PARA TRATAR _categoryExpenses.isEmpty
          if (_categoryExpenses.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'Nenhuma despesa registrada no último mês para exibir no gráfico.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            SizedBox(
              height: 200, // Altura do gráfico de pizza
              child: PieChart(
                PieChartData(
                  sectionsSpace: 0,
                  centerSpaceRadius: 40,
                  sections: _categoryExpenses.entries.map((entry) {
                    final isTouched =
                        false; // Pode ser usado para interatividade
                    final double fontSize = isTouched ? 18 : 14;
                    final double radius = isTouched ? 60 : 50;
                    final Color color = Colors.primaries[
                        _categoryExpenses.keys.toList().indexOf(entry.key) %
                            Colors.primaries.length];

                    return PieChartSectionData(
                      color: color,
                      value: entry.value,
                      title: totalExpenses > 0
                          ? '${(entry.value / totalExpenses * 100).toStringAsFixed(1)}%'
                          : '0.0%',
                      radius: radius,
                      titleStyle: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 2)
                        ],
                      ),
                      // CORREÇÃO FINAL AQUI: Usando Text diretamente para o badgeWidget
                      badgeWidget: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4.0, vertical: 2.0),
                        child: Text(
                          entry.key, // Nome da categoria
                          style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      badgePositionPercentageOffset:
                          1.4, // Ajusta a posição do rótulo da categoria
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 20),
          const Text(
            'Detalhes das Despesas:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (_categoryExpenses.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'Nenhum detalhe de despesa para exibir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            ..._categoryExpenses.entries.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: const TextStyle(fontSize: 16)),
                      Text('R\$ ${entry.value.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Financeira'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            UserAccountsDrawerHeader(
              accountName: Text(_userEmail ?? 'Usuário'),
              accountEmail: const Text(''), // Ou outro email se disponível
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 50, color: Colors.blue),
              ),
              decoration: const BoxDecoration(
                color: Colors.blue,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () {
                Navigator.pop(context); // Fecha o drawer
                setState(() {
                  _selectedIndex = 0; // Vai para a Dashboard
                });
                _fetchDashboardData(); // Recarrega dados da dashboard
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('Transações'),
              onTap: () async {
                Navigator.pop(context); // Fecha o drawer
                final bool? modified = await Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (context) => const TransactionsScreen()),
                );
                if (modified == true) {
                  _fetchDashboardData(); // Recarrega se transações foram alteradas
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_circle_down),
              title: const Text('Contas a Pagar'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (context) => const AccountsPayableScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_circle_up),
              title: const Text('Contas a Receber'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (context) => const AccountsReceivableScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.show_chart),
              title: const Text('Fluxo de Caixa'),
              onTap: () {
                Navigator.pop(context); // Fecha o drawer
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (context) => const CashFlowScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sair'),
              onTap: _signOut,
            ),
          ],
        ),
      ),
      // O body da HomeScreen sempre será o conteúdo da dashboard
      body: _buildDashboardContent(),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading
            ? null
            : () async {
                final bool? added = await Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (context) => const AddTransactionScreen()),
                );
                if (added == true) {
                  _fetchDashboardData(); // Recarrega a dashboard se uma transação foi adicionada
                }
              },
        child: const Icon(Icons.add),
      ),
    );
  }
}
