import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:saas_shinko/models/conta_a_pagar.dart';
import 'package:saas_shinko/models/categoria.dart'; // Para o dropdown de categorias

final SupabaseClient supabase = Supabase.instance.client;

class AddEditPayableScreen extends StatefulWidget {
  final ContaAPagar? contaAPagar; // Se for para editar, será não nulo

  const AddEditPayableScreen({Key? key, this.contaAPagar}) : super(key: key);

  @override
  State<AddEditPayableScreen> createState() => _AddEditPayableScreenState();
}

class _AddEditPayableScreenState extends State<AddEditPayableScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descricaoController = TextEditingController();
  final TextEditingController _valorController = TextEditingController();
  DateTime? _selectedDate;
  String? _selectedCategory; // ID da categoria
  String? _selectedStatus; // 'pendente', 'paga', 'cancelada'

  List<Categoria> _categoriasDisponiveis = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    if (widget.contaAPagar != null) {
      // Modo edição
      _descricaoController.text = widget.contaAPagar!.descricao;
      _valorController.text = widget.contaAPagar!.valor.toStringAsFixed(2);
      _selectedDate = widget.contaAPagar!.dataVencimento;
      _selectedCategory = widget.contaAPagar!.categoriaId;
      _selectedStatus = widget.contaAPagar!.status;
    } else {
      // Modo adição
      _selectedDate = DateTime.now();
      _selectedStatus = 'pendente'; // Padrão para nova conta
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

        if (widget.contaAPagar == null) {
          // Adicionar nova conta
          await supabase.from('contas_a_pagar').insert({
            'user_id': currentUser.id,
            'descricao': descricao,
            'valor': valor,
            'data_vencimento': DateFormat('yyyy-MM-dd').format(_selectedDate!),
            'categoria_id': _selectedCategory,
            'status': _selectedStatus,
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Conta a pagar adicionada com sucesso!')),
          );
        } else {
          // Editar conta existente
          await supabase
              .from('contas_a_pagar')
              .update({
                'descricao': descricao,
                'valor': valor,
                'data_vencimento':
                    DateFormat('yyyy-MM-dd').format(_selectedDate!),
                'categoria_id': _selectedCategory,
                'status': _selectedStatus,
              })
              .eq('id', widget.contaAPagar!.id)
              .eq('user_id', currentUser.id);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Conta a pagar atualizada com sucesso!')),
          );
        }
        Navigator.of(context).pop(true); // Indica que houve modificação
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar conta a pagar: $e')),
        );
        print('Erro ao salvar conta a pagar: $e');
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
        title: Text(widget.contaAPagar == null
            ? 'Adicionar Conta a Pagar'
            : 'Editar Conta a Pagar'),
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
                            ? 'Selecione a Data de Vencimento'
                            : 'Vencimento: ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}',
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _selectDate(context),
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
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Status'),
                      value: _selectedStatus,
                      items: const [
                        DropdownMenuItem(
                            value: 'pendente', child: Text('Pendente')),
                        DropdownMenuItem(value: 'paga', child: Text('Paga')),
                        DropdownMenuItem(
                            value: 'cancelada', child: Text('Cancelada')),
                      ],
                      onChanged: (newValue) {
                        setState(() {
                          _selectedStatus = newValue;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, selecione um status.';
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
                        child: Text(widget.contaAPagar == null
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
