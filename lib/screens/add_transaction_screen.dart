// lib/screens/add_transaction_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:saas_shinko/models/transacao.dart';
import 'package:saas_shinko/models/categoria.dart';

final SupabaseClient supabase = Supabase.instance.client;

class AddTransactionScreen extends StatefulWidget {
  final Transacao? transacao; // Para edição, será não nulo

  const AddTransactionScreen({Key? key, this.transacao}) : super(key: key);

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descricaoController = TextEditingController();
  final TextEditingController _valorController = TextEditingController();
  DateTime? _selectedDate;
  String? _selectedCategory; // ID da categoria
  String? _selectedType; // 'receita' ou 'despesa'

  List<Categoria> _categoriasDisponiveis = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    if (widget.transacao != null) {
      // Modo edição
      _descricaoController.text = widget.transacao!.descricao;
      _valorController.text = widget.transacao!.valor.toStringAsFixed(2);
      _selectedDate = widget.transacao!.data;
      _selectedCategory = widget.transacao!.categoriaId;
      _selectedType = widget.transacao!.tipo;
    } else {
      // Modo adição
      _selectedDate = DateTime.now();
      _selectedType = 'despesa'; // Valor padrão inicial
    }
  }

  @override
  void dispose() {
    _descricaoController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoading = true;
    });
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
        // Se estiver editando e a categoria selecionada não estiver na lista (ex: foi excluída)
        // ou se uma nova transação precisa de uma categoria padrão.
        if (_selectedCategory == null && _categoriasDisponiveis.isNotEmpty) {
          _selectedCategory = _categoriasDisponiveis.first.id;
        } else if (_selectedCategory != null &&
            !_categoriasDisponiveis.any((cat) => cat.id == _selectedCategory)) {
          // Se a categoria da transação editada não existe mais, limpa a seleção
          _selectedCategory = null;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar categorias: $e')),
      );
      print('Erro ao carregar categorias: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
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

      try {
        final double valor =
            double.parse(_valorController.text.replaceAll(',', '.'));
        final String descricao = _descricaoController.text.trim();

        if (widget.transacao == null) {
          // Adicionar nova transação
          await supabase.from('transacoes').insert({
            'user_id': currentUser.id,
            'descricao': descricao,
            'valor': valor,
            'data': DateFormat('yyyy-MM-dd').format(_selectedDate!),
            'categoria_id': _selectedCategory,
            'tipo': _selectedType,
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transação adicionada com sucesso!')),
          );
        } else {
          // Editar transação existente
          await supabase
              .from('transacoes')
              .update({
                'descricao': descricao,
                'valor': valor,
                'data': DateFormat('yyyy-MM-dd').format(_selectedDate!),
                'categoria_id': _selectedCategory,
                'tipo': _selectedType,
              })
              .eq('id', widget.transacao!.id)
              .eq('user_id', currentUser.id);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transação atualizada com sucesso!')),
          );
        }
        Navigator.of(context).pop(true); // Indica que houve modificação
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar transação: $e')),
        );
        print('Erro ao salvar transação: $e');
      } finally {
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _descricaoController,
                      decoration: const InputDecoration(labelText: 'Descrição'),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, insira uma descrição.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _valorController,
                      decoration: const InputDecoration(labelText: 'Valor'),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, insira um valor.';
                        }
                        if (double.tryParse(value.replaceAll(',', '.')) ==
                            null) {
                          return 'Por favor, insira um número válido.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text(
                        _selectedDate == null
                            ? 'Selecione a Data'
                            : 'Data: ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _selectDate(context),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Tipo'),
                      value: _selectedType,
                      items: const [
                        DropdownMenuItem(
                            value: 'receita', child: Text('Receita')),
                        DropdownMenuItem(
                            value: 'despesa', child: Text('Despesa')),
                      ],
                      onChanged: (newValue) {
                        setState(() {
                          _selectedType = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, selecione um tipo.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Categoria'),
                      value: _selectedCategory,
                      items: _categoriasDisponiveis.map((categoria) {
                        return DropdownMenuItem<String>(
                          value: categoria.id,
                          child: Text(categoria.nome),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _selectedCategory = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, selecione uma categoria.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 15),
                          textStyle: const TextStyle(fontSize: 18),
                        ),
                        child: Text(widget.transacao == null
                            ? 'Adicionar'
                            : 'Atualizar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
