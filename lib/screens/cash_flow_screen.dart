// lib/screens/cash_flow_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:saas_shinko/models/transacao.dart'; // Importe o modelo de Transacao

final SupabaseClient supabase = Supabase.instance.client;

class CashFlowScreen extends StatefulWidget {
  const CashFlowScreen({super.key});

  @override
  State<CashFlowScreen> createState() => _CashFlowScreenState();
}

class _CashFlowScreenState extends State<CashFlowScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  List<Transacao> _transactions = [];
  bool _isLoading = false;
  Map<String, double> _dailyCashFlow =
      {}; // Data (yyyy-MM-dd) -> Saldo acumulado
  List<String> _sortedDates = []; // Para manter a ordem das datas no gráfico

  @override
  void initState() {
    super.initState();
    _fetchCashFlowData();
  }

  Future<void> _fetchCashFlowData() async {
    setState(() {
      _isLoading = true;
      _dailyCashFlow = {}; // Limpa dados anteriores
      _sortedDates = [];
    });

    try {
      final User? currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        throw 'Usuário não autenticado!';
      }

      final String formattedStartDate =
          DateFormat('yyyy-MM-dd').format(_startDate);
      final String formattedEndDate = DateFormat('yyyy-MM-dd').format(_endDate);

      final List<dynamic> response = await supabase
          .from('transacoes')
          .select('*')
          .eq('user_id', currentUser.id)
          .gte('data', formattedStartDate)
          .lte('data', formattedEndDate)
          .order('data', ascending: true);

      _transactions = response.map((json) => Transacao.fromJson(json)).toList();

      // --- Lógica para calcular o fluxo de caixa diário acumulado ---
      Map<String, double> dailyChange =
          {}; // Armazena a mudança líquida por dia

      // Inicializa todas as datas no intervalo com 0.0
      for (int i = 0; i <= _endDate.difference(_startDate).inDays; i++) {
        final date = _startDate.add(Duration(days: i));
        dailyChange[DateFormat('yyyy-MM-dd').format(date)] = 0.0;
      }

      // Preenche dailyChange com as transações
      for (var transaction in _transactions) {
        final String dateKey =
            DateFormat('yyyy-MM-dd').format(transaction.data);
        if (dailyChange.containsKey(dateKey)) {
          // Garante que a data está dentro do intervalo
          if (transaction.tipo == 'receita') {
            dailyChange[dateKey] =
                (dailyChange[dateKey] ?? 0.0) + transaction.valor;
          } else {
            dailyChange[dateKey] =
                (dailyChange[dateKey] ?? 0.0) - transaction.valor;
          }
        }
      }

      // Ordena as chaves de dailyChange para garantir a sequência correta no gráfico
      _sortedDates = dailyChange.keys.toList()..sort();

      // Calcula o saldo acumulado
      double runningBalance = 0.0;

      for (final dateKey in _sortedDates) {
        runningBalance += dailyChange[dateKey]!;
        _dailyCashFlow[dateKey] = runningBalance;
      }

      // --- Debug Prints para o console ---
      print('--- Fluxo de Caixa Data Fetched ---');
      print('Start Date: $_startDate, End Date: $_endDate');
      print('Raw Transactions: $_transactions');
      print('Daily Changes (before accumulation): $dailyChange');
      print('Sorted Dates: $_sortedDates');
      print('Accumulated Daily Cash Flow: $_dailyCashFlow');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar fluxo de caixa: $e')),
      );
      print('Erro ao carregar fluxo de caixa: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000, 1, 1), // Data inicial mais razoável
      lastDate: DateTime(2101, 12, 31), // Data final mais razoável
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      helpText: 'Selecione o Período',
      confirmText: 'Confirmar',
      cancelText: 'Cancelar',
    );
    if (picked != null &&
        (picked.start != _startDate || picked.end != _endDate)) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _fetchCashFlowData(); // Recarrega os dados com o novo período
    }
  }

  // Ajuste de minY e maxY para dar uma margem no gráfico
  double _getMinY() {
    if (_dailyCashFlow.isEmpty) return 0;
    double minVal = _dailyCashFlow.values.reduce((a, b) => a < b ? a : b);
    // Adiciona uma margem, garante que o zero seja visível se os valores forem mistos
    if (minVal == 0 && _dailyCashFlow.values.every((val) => val == 0)) return 0;
    return minVal < 0 ? minVal * 1.1 : (minVal > 0 ? minVal * 0.9 : 0);
  }

  double _getMaxY() {
    if (_dailyCashFlow.isEmpty) return 0;
    double maxVal = _dailyCashFlow.values.reduce((a, b) => a > b ? a : b);
    // Adiciona uma margem, garante que o zero seja visível se os valores forem mistos
    if (maxVal == 0 && _dailyCashFlow.values.every((val) => val == 0)) return 0;
    return maxVal > 0 ? maxVal * 1.1 : (maxVal < 0 ? maxVal * 0.9 : 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fluxo de Caixa'),
        actions: [
          IconButton(
            icon: const Icon(
                Icons.calendar_today), // Ícone de calendário mais genérico
            onPressed: _isLoading ? null : () => _selectDateRange(context),
            tooltip: 'Selecionar Período',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator()) // Exibe indicador de carregamento
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Período: ${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    flex: 2, // Ocupa mais espaço para o gráfico
                    child: _dailyCashFlow.isEmpty ||
                            _sortedDates.length <
                                2 // Precisa de pelo menos 2 pontos para uma linha
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text(
                                'Nenhum dado de fluxo de caixa para o período selecionado ou dados insuficientes para o gráfico.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 16, fontStyle: FontStyle.italic),
                              ),
                            ),
                          )
                        : LineChart(
                            LineChartData(
                              gridData: const FlGridData(show: false),
                              titlesData: FlTitlesData(
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                          'R\$${value.toStringAsFixed(0)}', // Arredonda para não ter muitas casas decimais
                                          style: const TextStyle(fontSize: 10));
                                    },
                                    reservedSize: 40,
                                  ),
                                ),
                                topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                              ),
                              borderData: FlBorderData(
                                show: true,
                                border: Border.all(
                                    color: const Color(0xff37434d), width: 1),
                              ),
                              minX: 0,
                              maxX: (_sortedDates.length > 0
                                  ? (_sortedDates.length - 1).toDouble()
                                  : 0), // Garante maxX não seja negativo
                              minY: _getMinY(), // Usa o cálculo ajustado
                              maxY: _getMaxY(), // Usa o cálculo ajustado
                              lineBarsData: [
                                LineChartBarData(
                                  spots: List.generate(_sortedDates.length,
                                      (index) {
                                    final dateKey = _sortedDates[index];
                                    // Certifica-se de que a chave existe e o valor não é nulo
                                    if (_dailyCashFlow.containsKey(dateKey) &&
                                        _dailyCashFlow[dateKey] != null) {
                                      return FlSpot(index.toDouble(),
                                          _dailyCashFlow[dateKey]!);
                                    }
                                    return FlSpot(index.toDouble(),
                                        0); // Retorna 0 se o dado estiver faltando
                                  }),
                                  isCurved: true,
                                  color: Colors.blueAccent,
                                  barWidth: 3,
                                  isStrokeCapRound: true,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                      show: true,
                                      color:
                                          Colors.blueAccent.withOpacity(0.3)),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Resumo das Transações:',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    flex: 1, // Ocupa menos espaço para a lista
                    child: _transactions.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Text(
                                'Nenhuma transação encontrada para o período selecionado.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 16, fontStyle: FontStyle.italic),
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _transactions.length,
                            itemBuilder: (context, index) {
                              final transacao = _transactions[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  leading: Icon(
                                    transacao.tipo == 'receita'
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    color: transacao.tipo == 'receita'
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                  title: Text(transacao.descricao),
                                  subtitle: Text(
                                    '${DateFormat('dd/MM/yyyy').format(transacao.data)} - Categoria: ${transacao.categoriaId ?? 'N/A'}',
                                  ),
                                  trailing: Text(
                                    '${transacao.tipo == 'receita' ? '+' : '-'} R\$ ${transacao.valor.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: transacao.tipo == 'receita'
                                          ? Colors.green
                                          : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
