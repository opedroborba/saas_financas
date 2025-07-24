import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:saas_shinko/models/categoria.dart';
import 'package:saas_shinko/models/transacao.dart';

final SupabaseClient supabase = Supabase.instance.client;

class AddTransactionScreen extends StatefulWidget {
  final Transacao? transacao; // Parâmetro opcional para edição

  const AddTransactionScreen({Key? key, this.transacao}) : super(key: key);

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedType = 'despesa'; // 'receita' ou 'despesa'
  String? _selectedCategoryId; // ID da categoria selecionada

  List<Categoria> _categorias = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();

    // Se uma transação foi passada, preencher os campos para edição
    if (widget.transacao != null) {
      _descriptionController.text = widget.transacao!.descricao;
      _valueController.text = widget.transacao!.valor.toString();
      _selectedDate = widget.transacao!.data;
      _selectedType = widget.transacao!.tipo;
      _selectedCategoryId = widget.transacao!.categoriaId;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    final User? currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      // Tratar caso de usuário não logado
      return;
    }
    try {
      final List<dynamic> response = await supabase
          .from('categorias')
          .select()
          .eq('user_id', currentUser.id)
          .order('nome', ascending: true);
      setState(() {
        _categorias = response.map((json) => Categoria.fromJson(json)).toList();
      });
      // Se estiver editando e a categoria selecionada for nula,
      // mas a transacao original tem categoriaId, tente selecioná-la.
      if (widget.transacao != null && _selectedCategoryId == null) {
        if (widget.transacao!.categoriaId != null &&
            _categorias.any((cat) => cat.id == widget.transacao!.categoriaId)) {
          setState(() {
            _selectedCategoryId = widget.transacao!.categoriaId;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar categorias: $e')),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveTransaction() async {
    setState(() {
      _isLoading = true;
    });

    final User? currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: Usuário não autenticado.')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    if (_descriptionController.text.trim().isEmpty ||
        _valueController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, preencha todos os campos.')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final double? valor = double.tryParse(_valueController.text.trim());
    if (valor == null || valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, insira um valor válido.')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final transactionData = {
        'user_id': currentUser.id,
        'descricao': _descriptionController.text.trim(),
        'valor': valor,
        'data': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'tipo': _selectedType,
        'categoria_id': _selectedCategoryId,
      };

      if (widget.transacao == null) {
        // Adicionar nova transação
        await supabase.from('transacoes').insert(transactionData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transação adicionada com sucesso!')),
        );
      } else {
        // Atualizar transação existente
        await supabase
            .from('transacoes')
            .update(transactionData)
            .eq('id', widget.transacao!.id); // Usar o ID da transação existente
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transação atualizada com sucesso!')),
        );
      }

      Navigator.of(context)
          .pop(true); // Indica que a transação foi adicionada/modificada
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar transação: $e')),
      );
      print('Erro ao salvar transação: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transacao == null
            ? 'Adicionar Transação'
            : 'Editar Transação'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _valueController,
                    decoration: const InputDecoration(
                      labelText: 'Valor (R\$)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(
                      'Data: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () => _selectDate(context),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedType,
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedType = newValue!;
                      });
                    },
                    items: const [
                      DropdownMenuItem(
                          value: 'despesa', child: Text('Despesa')),
                      DropdownMenuItem(
                          value: 'receita', child: Text('Receita')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Categoria',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedCategoryId,
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedCategoryId = newValue;
                      });
                    },
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Nenhuma Categoria')),
                      ..._categorias.map((categoria) => DropdownMenuItem(
                            value: categoria.id,
                            child: Text(categoria.nome),
                          )),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveTransaction,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: Text(
                        widget.transacao == null
                            ? 'Adicionar Transação'
                            : 'Salvar Alterações',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
