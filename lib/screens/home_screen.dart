import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:saas_shinko/screens/auth_screen.dart';
import 'package:saas_shinko/models/transacao.dart';
import 'package:saas_shinko/screens/add_transaction_screen.dart';
import 'package:saas_shinko/models/categoria.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:saas_shinko/screens/category_management_screen.dart';

// Imports para Geração de PDF
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';
import 'package:printing/printing.dart'; // NOVO: Para funcionalidades de impressão/visualização de PDF

// Para uso condicional de dart:io e path_provider (se você precisar de funcionalidade de arquivo para mobile)
import 'dart:io' show File; // Importa File do dart:io
import 'package:path_provider/path_provider.dart'; // Importa path_provider
import 'package:flutter/foundation.dart' show kIsWeb; // Verifica se está na web

final SupabaseClient supabase = Supabase.instance.client;

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedCategoryFilterId;
  String? _selectedTypeFilter;

  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  late Future<List<Map<String, dynamic>>> _transacoesFuture;
  List<Categoria> _categoriasDisponiveis = [];

  double _saldoTotal = 0.0;
  double _totalReceitas = 0.0;
  double _totalDespesas = 0.0;
  Map<String, double> _expenseCategoryData = {};
  Map<int, Map<String, double>> _monthlyData = {};

  bool _isLoading =
      false; // Variável para controlar o estado de carregamento (ex: ao gerar PDF)

  // === DEFINIÇÕES DE CORES PARA HARMONIA (devem ser as mesmas do main.dart) ===
  static const Color primaryOrange = Color(0xFFF7A102);
  static const Color secondaryDarkBlue = Color(0xFF1A237E);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color dangerRed = Color(0xFFD32F2F);
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Definindo o período inicial como o ano atual completo
    _startDate = DateTime(now.year, 1, 1);
    _endDate = DateTime(now.year, 12, 31, 23, 59, 59, 999);

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
        _transacoesFuture = _fetchTransactions();
      });
    }
  }

  Future<void> _loadInitialData() async {
    await _fetchCategories();
    _transacoesFuture = _fetchTransactions();
    setState(() {}); // Força a reconstrução para exibir dados após carregar
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
      setState(() {
        _saldoTotal = 0.0;
        _totalReceitas = 0.0;
        _totalDespesas = 0.0;
        _expenseCategoryData = {};
        _monthlyData = {};
      });
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

      final List<dynamic> response =
          await query.order('data', ascending: false).limit(500);

      double receitas = 0.0;
      double despesas = 0.0;
      final List<Map<String, dynamic>> processedTransacoes = [];
      Map<String, double> tempExpenseCategoryData = {};
      Map<int, Map<String, double>> tempMonthlyData = {};

      for (var jsonItem in response) {
        final transacao = Transacao.fromJson(jsonItem);

        Map<String, dynamic> itemWithCategory =
            Map<String, dynamic>.from(jsonItem);
        if (jsonItem['categorias'] != null &&
            jsonItem['categorias']['nome'] != null) {
          itemWithCategory['categoria_nome'] = jsonItem['categorias']['nome'];
        } else {
          itemWithCategory['categoria_nome'] = 'Sem Categoria';
        }

        // Aplicar filtros de tipo e categoria AQUI, antes de processar os totais
        bool matchesType = _selectedTypeFilter == null ||
            transacao.tipo == _selectedTypeFilter;
        bool matchesCategory = _selectedCategoryFilterId == null ||
            transacao.categoriaId == _selectedCategoryFilterId;

        if (matchesType && matchesCategory) {
          processedTransacoes
              .add(itemWithCategory); // Só adiciona se passar nos filtros

          if (transacao.tipo == 'receita') {
            receitas += transacao.valor;
          } else {
            despesas += transacao.valor;
            String categoryName = itemWithCategory['categoria_nome'] as String;
            tempExpenseCategoryData.update(
              categoryName,
              (value) => value + transacao.valor,
              ifAbsent: () => transacao.valor,
            );
          }
        }

        // Dados para o gráfico mensal (apenas pelo período de data, não pelos outros filtros)
        final int month = transacao.data.month;
        tempMonthlyData.putIfAbsent(
            month, () => {'receita': 0.0, 'despesa': 0.0});
        if (transacao.tipo == 'receita') {
          tempMonthlyData[month]!['receita'] =
              tempMonthlyData[month]!['receita']! + transacao.valor;
        } else {
          tempMonthlyData[month]!['despesa'] =
              tempMonthlyData[month]!['despesa']! + transacao.valor;
        }
      }

      setState(() {
        _totalReceitas = receitas;
        _totalDespesas = despesas;
        _saldoTotal = receitas - despesas;
        _expenseCategoryData = tempExpenseCategoryData;
        _monthlyData = tempMonthlyData;
      });

      return processedTransacoes;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar transações: $e')),
      );
      print('Erro ao carregar transações: $e');
      setState(() {
        _saldoTotal = 0.0;
        _totalReceitas = 0.0;
        _totalDespesas = 0.0;
        _expenseCategoryData = {};
        _monthlyData = {};
      });
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
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir transação: $e')),
        );
        print('Erro ao excluir transação: $e');
        setState(() {
          _transacoesFuture =
              _fetchTransactions(); // Recarrega as transações mesmo com erro para garantir consistência
        });
      }
    } else {
      // Se a exclusão for cancelada, apenas recarregamos para garantir que a lista esteja atualizada caso algo tenha mudado
      setState(() {
        _transacoesFuture = _fetchTransactions();
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
          (Route<dynamic> route) => false,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logout realizado com sucesso!')),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro inesperado ao fazer logout: $e')),
        );
      }
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

  Color _getRandomColor(int index) {
    // Estas cores são para o gráfico de pizza, podem ser diferentes das cores do tema
    List<Color> colors = [
      Colors.blue,
      Colors.green,
      Colors.red,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.brown,
      Colors.indigo,
      Colors.cyan,
      Colors.lime,
      Colors.pink,
      Colors.amber,
    ];
    return colors[index % colors.length];
  }

  String getMonthName(int monthNum) {
    switch (monthNum) {
      case 1:
        return 'Jan';
      case 2:
        return 'Fev';
      case 3:
        return 'Mar';
      case 4:
        return 'Abr';
      case 5:
        return 'Mai';
      case 6:
        return 'Jun';
      case 7:
        return 'Jul';
      case 8:
        return 'Ago';
      case 9:
        return 'Set';
      case 10:
        return 'Out';
      case 11:
        return 'Nov';
      case 12:
        return 'Dez';
      default:
        return '';
    }
  }

  // --- FUNÇÃO PARA GERAR E UPLOAD DE PDF ---
  Future<void> _generateAndUploadPdfReport() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final pdf = pw.Document();
      final List<Map<String, dynamic>> transacoes = await _transacoesFuture;

      final formatCurrency =
          NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
      final formatDateTime = DateFormat('dd/MM/yyyy');

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Relatório de Transações - Shinkō Finanças',
                      style: pw.TextStyle(
                          fontSize: 24, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      'Período: ${formatDateTime.format(_startDate!)} a ${formatDateTime.format(_endDate!)}',
                      style: pw.TextStyle(fontSize: 14),
                    ),
                    pw.SizedBox(height: 20),
                  ],
                ),
              ),
              // Adicionar Tabela de Resumo
              pw.Table.fromTextArray(
                headers: ['Resumo', 'Valor'],
                data: <List<String>>[
                  ['Receitas Totais', formatCurrency.format(_totalReceitas)],
                  ['Despesas Totais', formatCurrency.format(_totalDespesas)],
                  ['Saldo Atual', formatCurrency.format(_saldoTotal)],
                ],
                border: pw.TableBorder.all(color: PdfColors.grey),
                headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.grey700),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.all(8),
              ),
              pw.SizedBox(height: 30),
              pw.Text(
                'Detalhamento das Transações:',
                style:
                    pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              // Adicionar Tabela de Transações
              pw.Table.fromTextArray(
                headers: ['Data', 'Descrição', 'Categoria', 'Tipo', 'Valor'],
                data: transacoes.map((t) {
                  final Transacao transacao = Transacao.fromJson(t);
                  final String categoriaNome = t['categorias'] != null
                      ? t['categorias']['nome']
                      : 'Sem Categoria';
                  return [
                    formatDateTime.format(transacao.data),
                    transacao.descricao,
                    categoriaNome,
                    transacao.tipo == 'receita' ? 'Receita' : 'Despesa',
                    formatCurrency.format(transacao.valor),
                  ];
                }).toList(),
                border: pw.TableBorder.all(color: PdfColors.grey),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.grey300),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.all(8),
                columnWidths: {
                  0: const pw.FixedColumnWidth(80), // Data
                  1: const pw.FlexColumnWidth(3), // Descrição
                  2: const pw.FlexColumnWidth(2), // Categoria
                  3: const pw.FixedColumnWidth(60), // Tipo
                  4: const pw.FixedColumnWidth(100), // Valor
                },
              ),
              // Rodapé (opcional)
              pw.Spacer(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Gerado por Shinkō Finanças em ${formatDateTime.format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            ];
          },
        ),
      );

      final User? currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        throw 'Usuário não autenticado. Impossível enviar relatório.';
      }

      final pdfBytes = await pdf.save(); // Salva o PDF como bytes

      if (kIsWeb) {
        // Lógica para Web: Exibir/Baixar diretamente no navegador
        await Printing.layoutPdf(
            onLayout: (PdfPageFormat format) async => pdfBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Relatório PDF gerado e exibido no navegador!')),
          );
        }
      } else {
        // Lógica para Mobile/Desktop: Salvar em arquivo e fazer upload
        final directory = await getTemporaryDirectory();
        final path =
            '${directory.path}/relatorio_financas_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
        final file = File(path);
        await file.writeAsBytes(pdfBytes);

        // Upload para o Supabase Storage
        final fileName = path.split('/').last; // Nome do arquivo para o bucket
        final String bucketPath = 'relatorios/$fileName';

        await supabase.storage.from('relatorios').upload(
              bucketPath,
              file,
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'application/pdf',
              ),
            );

        final String publicUrl =
            supabase.storage.from('relatorios').getPublicUrl(bucketPath);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Relatório PDF gerado e enviado com sucesso!')),
          );

          if (await canLaunchUrl(Uri.parse(publicUrl))) {
            await launchUrl(Uri.parse(publicUrl),
                mode: LaunchMode.externalApplication);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text('Não foi possível abrir o PDF. URL: $publicUrl')),
            );
          }
        }
      }
    } on StorageException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao fazer upload do PDF: ${e.message}')),
        );
      }
      print('Erro ao fazer upload do PDF: ${e.message}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar ou enviar relatório: $e')),
        );
      }
      print('Erro ao gerar/enviar PDF: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  // --- FIM DA FUNÇÃO PARA GERAR E UPLOAD DE PDF ---

  // NOVO WIDGET PARA A SEÇÃO DE TRANSAÇÕES COM FILTROS
  Widget get transactionsSectionWithFilters {
    final formatCurrency =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final formatDateTime = DateFormat('dd/MM/yyyy');

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Minhas Transações',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Filtros
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              // Filtro de Data Início
              ElevatedButton.icon(
                onPressed: () => _selectDate(context, isStartDate: true),
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  _startDate == null
                      ? 'Data Início'
                      : 'De: ${formatDateTime.format(_startDate!)}',
                ),
              ),
              // Filtro de Data Fim
              ElevatedButton.icon(
                onPressed: () => _selectDate(context, isStartDate: false),
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
                  DropdownMenuItem(value: null, child: Text('Todos os Tipos')),
                  DropdownMenuItem(value: 'receita', child: Text('Receita')),
                  DropdownMenuItem(value: 'despesa', child: Text('Despesa')),
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
                  const DropdownMenuItem(
                      value: null, child: Text('Todas as Categorias')),
                  ..._categoriasDisponiveis.map((categoria) => DropdownMenuItem(
                        value: categoria.id,
                        child: Text(categoria.nome),
                      )),
                ],
              ),
              // Campo de Busca
              SizedBox(
                width: 200, // Largura fixa para o campo de busca
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
                                _transacoesFuture = _fetchTransactions();
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
          // Lista de Transações
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _transacoesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(
                    child:
                        Text('Erro ao carregar transações: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                    child: Text('Nenhuma transação encontrada.'));
              } else {
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final transacaoMap = snapshot.data![index];
                    final transacao = Transacao.fromJson(transacaoMap);
                    final categoriaNome = transacaoMap['categorias'] != null
                        ? transacaoMap['categorias']['nome']
                        : 'Sem Categoria';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      elevation: 2,
                      child: ListTile(
                        leading: Icon(
                          transacao.tipo == 'receita'
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color: transacao.tipo == 'receita'
                              ? successGreen // Cor para receita
                              : dangerRed, // Cor para despesa
                        ),
                        title: Text(
                          transacao.descricao,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                              builder: (context) => AddTransactionScreen(
                                transacao:
                                    transacao, // Passando o objeto transacao para edição
                              ),
                            ),
                          );
                          if (transactionModified == true) {
                            setState(() {
                              _transacoesFuture = _fetchTransactions();
                            });
                          }
                        },
                        onLongPress: () => _deleteTransaction(transacao.id),
                      ),
                    );
                  },
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize:
              MainAxisSize.min, // Para que o Row não ocupe toda a largura
          children: [
            // Logotipo puxado da URL
            Image.network(
              'https://hqlvkxckmprqldqrxchh.supabase.co/storage/v1/object/public/imagens//1.png',
              height: 30, // Altura do logotipo
              // errorBuilder é útil para ver se há problemas ao carregar a imagem
              errorBuilder: (BuildContext context, Object exception,
                  StackTrace? stackTrace) {
                print('Erro ao carregar imagem: $exception'); // Para depuração
                return const SizedBox(
                  width: 30,
                  height: 30,
                  child: Icon(Icons.broken_image,
                      color: Colors.white), // Ícone em caso de erro
                );
              },
            ),
            const SizedBox(width: 8), // Espaçamento entre o logo e o texto
            const Text('Shinkō Finanças'), // Novo nome do aplicativo
          ],
        ),
        actions: [
          // Botão para Gerar PDF
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _isLoading
                ? null
                : _generateAndUploadPdfReport, // Desabilita se estiver carregando
            tooltip: 'Gerar Relatório PDF',
          ),
          // Botão de Refresh
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading
                ? null
                : () {
                    // Desabilita se estiver carregando
                    setState(() {
                      _transacoesFuture = _fetchTransactions();
                    });
                  },
            tooltip: 'Recarregar Transações',
          ),
          // Botão para Gerenciamento de Categorias
          IconButton(
            icon: const Icon(Icons.category), // Ícone de categoria
            onPressed: _isLoading
                ? null
                : () async {
                    // Desabilita se estiver carregando
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (context) =>
                              const CategoryManagementScreen()),
                    );
                    // Recarrega dados após retornar da tela de categorias
                    setState(() {
                      _transacoesFuture = _fetchTransactions();
                      _loadInitialData();
                    });
                  },
            tooltip: 'Gerenciar Categorias',
          ),
          // Botão de Logout
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _isLoading
                ? null
                : _signOut, // Desabilita se estiver carregando
            tooltip: 'Sair',
          ),
        ],
      ),
      body:
          _isLoading // Adiciona um indicador de carregamento na tela principal
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Expanded(
                                child: _buildSummaryCard(
                                    'Receitas',
                                    _totalReceitas,
                                    successGreen)), // Usando successGreen
                            const SizedBox(width: 10),
                            Expanded(
                                child: _buildSummaryCard(
                                    'Despesas',
                                    _totalDespesas,
                                    dangerRed)), // Usando dangerRed
                            const SizedBox(width: 10),
                            Expanded(
                                child: _buildSummaryCard(
                                    'Saldo',
                                    _saldoTotal,
                                    _saldoTotal >= 0
                                        ? primaryOrange
                                        : dangerRed)), // Saldo positivo com laranja, negativo com vermelho
                          ],
                        ),
                      ),
                      const Divider(),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          const double breakpoint = 700;

                          final Widget chartSection = Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Despesas por Categoria',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                _expenseCategoryData.isEmpty ||
                                        _totalDespesas == 0
                                    ? Container(
                                        height: 200,
                                        alignment: Alignment.center,
                                        child: const Text(
                                            'Nenhuma despesa para exibir no gráfico de pizza neste período.'),
                                      )
                                    : SizedBox(
                                        height: 250,
                                        child: PieChart(
                                          PieChartData(
                                            sections: _expenseCategoryData
                                                .entries
                                                .toList()
                                                .asMap()
                                                .entries
                                                .map((entry) {
                                              int index = entry.key;
                                              MapEntry<String, double> data =
                                                  entry.value;
                                              final double percentage =
                                                  (data.value /
                                                          _totalDespesas) *
                                                      100;
                                              return PieChartSectionData(
                                                color: _getRandomColor(
                                                    index), // Gráfico de pizza usa cores variadas
                                                value: data.value,
                                                title:
                                                    '${data.key}\n${percentage.toStringAsFixed(1)}%',
                                                radius: 50,
                                                titleStyle: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                                titlePositionPercentageOffset:
                                                    0.6,
                                              );
                                            }).toList(),
                                            sectionsSpace: 2,
                                            centerSpaceRadius: 40,
                                            pieTouchData:
                                                PieTouchData(enabled: false),
                                          ),
                                        ),
                                      ),
                                const SizedBox(height: 20),
                                const Text(
                                  'Receitas vs. Despesas Mensais',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                _monthlyData.isEmpty
                                    ? Container(
                                        height: 200,
                                        alignment: Alignment.center,
                                        child: const Text(
                                            'Nenhum dado mensal para exibir no gráfico de barras neste período.'),
                                      )
                                    : SizedBox(
                                        height: 250,
                                        child: BarChart(
                                          BarChartData(
                                            alignment:
                                                BarChartAlignment.spaceAround,
                                            maxY: _monthlyData.values
                                                    .map((e) => [
                                                          e['receita'] ?? 0,
                                                          e['despesa'] ?? 0
                                                        ])
                                                    .expand((e) => e)
                                                    .reduce((a, b) =>
                                                        a > b ? a : b) *
                                                1.2,
                                            barTouchData:
                                                BarTouchData(enabled: false),
                                            titlesData: FlTitlesData(
                                              show: true,
                                              bottomTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: true,
                                                  getTitlesWidget:
                                                      (value, meta) {
                                                    return SideTitleWidget(
                                                      axisSide: meta.axisSide,
                                                      space: 4,
                                                      child: Text(
                                                          getMonthName(
                                                              value.toInt()),
                                                          style:
                                                              const TextStyle(
                                                                  fontSize:
                                                                      10)),
                                                    );
                                                  },
                                                  interval: 1,
                                                ),
                                              ),
                                              leftTitles: AxisTitles(
                                                sideTitles: SideTitles(
                                                  showTitles: true,
                                                  getTitlesWidget:
                                                      (value, meta) {
                                                    return Text(
                                                        'R\$${value.toInt()}',
                                                        style: const TextStyle(
                                                            fontSize: 10));
                                                  },
                                                  reservedSize: 40,
                                                ),
                                              ),
                                              topTitles: const AxisTitles(
                                                  sideTitles: SideTitles(
                                                      showTitles: false)),
                                              rightTitles: const AxisTitles(
                                                  sideTitles: SideTitles(
                                                      showTitles: false)),
                                            ),
                                            gridData:
                                                const FlGridData(show: false),
                                            borderData: FlBorderData(
                                              show: true,
                                              border: const Border(
                                                bottom: BorderSide(
                                                    color: Colors.black,
                                                    width: 1),
                                                left: BorderSide(
                                                    color: Colors.black,
                                                    width: 1),
                                              ),
                                            ),
                                            barGroups: _monthlyData.entries
                                                .map((entry) {
                                              final int month = entry.key;
                                              final double receita =
                                                  entry.value['receita'] ?? 0.0;
                                              final double despesa =
                                                  entry.value['despesa'] ?? 0.0;

                                              return BarChartGroupData(
                                                x: month,
                                                barRods: [
                                                  BarChartRodData(
                                                    toY: receita,
                                                    color:
                                                        successGreen, // Gráfico de barras com as novas cores
                                                    width: 8,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            2),
                                                  ),
                                                  BarChartRodData(
                                                    toY: despesa,
                                                    color:
                                                        dangerRed, // Gráfico de barras com as novas cores
                                                    width: 8,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            2),
                                                  ),
                                                ],
                                                barsSpace: 4,
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                          );

                          if (constraints.maxWidth > breakpoint) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: chartSection),
                                const VerticalDivider(),
                                Expanded(
                                    child:
                                        transactionsSectionWithFilters), // Usando o getter
                              ],
                            );
                          } else {
                            return Column(
                              children: [
                                chartSection,
                                const Divider(),
                                transactionsSectionWithFilters, // Usando o getter
                              ],
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading
            ? null
            : () async {
                // Desabilita se estiver carregando
                final bool? transactionAdded = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AddTransactionScreen(),
                  ),
                );
                if (transactionAdded == true) {
                  setState(() {
                    _transacoesFuture = _fetchTransactions();
                  });
                }
              },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryCard(String title, double value, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'R\$ ${value.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
