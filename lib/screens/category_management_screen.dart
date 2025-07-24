// File: lib/screens/category_management_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:saas_shinko/models/categoria.dart'; // Certifique-se que o caminho está correto

final SupabaseClient supabase = Supabase.instance.client;

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({Key? key}) : super(key: key);

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  late Future<List<Categoria>> _categoriasFuture;
  final TextEditingController _categoryNameController = TextEditingController();
  String _selectedCategoryType = 'despesa'; // Default type for new categories

  @override
  void initState() {
    super.initState();
    _categoriasFuture = _fetchCategories();
  }

  // --- Função para buscar categorias ---
  Future<List<Categoria>> _fetchCategories() async {
    final User? currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Usuário não autenticado. Impossível carregar categorias.')),
      );
      return [];
    }

    try {
      final List<dynamic> response = await supabase
          .from('categorias')
          .select()
          .eq('user_id', currentUser.id)
          .order('nome', ascending: true);

      return response.map((json) => Categoria.fromJson(json)).toList();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar categorias: $e')),
      );
      print('Erro ao carregar categorias: $e');
      return [];
    }
  }

  // --- Função para adicionar categoria ---
  Future<void> _addCategory() async {
    final User? currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Você precisa estar logado para adicionar categorias.')),
      );
      return;
    }

    if (_categoryNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('O nome da categoria não pode ser vazio.')),
      );
      return;
    }

    try {
      await supabase.from('categorias').insert({
        'nome': _categoryNameController.text.trim(),
        'tipo': _selectedCategoryType,
        'user_id': currentUser.id,
      });

      _categoryNameController.clear(); // Limpa o campo de texto
      setState(() {
        _categoriasFuture = _fetchCategories(); // Recarrega a lista
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Categoria adicionada com sucesso!')),
      );
      Navigator.of(context).pop(); // Fecha o diálogo/modal
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao adicionar categoria: $e')),
      );
      print('Erro ao adicionar categoria: $e');
    }
  }

  // --- Função para editar categoria ---
  Future<void> _editCategory(Categoria categoria) async {
    final User? currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Você precisa estar logado para editar categorias.')),
      );
      return;
    }

    // Preenche os controladores com os dados da categoria existente
    _categoryNameController.text = categoria.nome;
    String newCategoryType = categoria.tipo; // Valor inicial do dropdown

    String? tempCategoryName =
        categoria.nome; // Para capturar a mudança no TextField

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Editar Categoria'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setStateInDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _categoryNameController,
                    decoration:
                        const InputDecoration(labelText: 'Nome da Categoria'),
                    onChanged: (value) =>
                        tempCategoryName = value, // Captura a mudança
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: newCategoryType,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: const [
                      DropdownMenuItem(
                          value: 'receita', child: Text('Receita')),
                      DropdownMenuItem(
                          value: 'despesa', child: Text('Despesa')),
                    ],
                    onChanged: (String? newValue) {
                      setStateInDialog(() {
                        newCategoryType =
                            newValue!; // Atualiza o tipo no diálogo
                      });
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _categoryNameController
                    .clear(); // Limpa após fechar (se o usuário cancelar)
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (tempCategoryName == null ||
                    tempCategoryName!.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('O nome da categoria não pode ser vazio.')),
                  );
                  return;
                }

                try {
                  await supabase
                      .from('categorias')
                      .update({
                        'nome': tempCategoryName!.trim(),
                        'tipo': newCategoryType,
                      })
                      .eq('id', categoria.id)
                      .eq('user_id', currentUser.id);

                  setState(() {
                    _categoriasFuture = _fetchCategories(); // Recarrega a lista
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Categoria atualizada com sucesso!')),
                  );
                  Navigator.of(dialogContext).pop(); // Fecha o diálogo
                  _categoryNameController.clear(); // Limpa após salvar
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao atualizar categoria: $e')),
                  );
                  print('Erro ao atualizar categoria: $e');
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  // --- Função para excluir categoria ---
  Future<void> _deleteCategory(String categoryId) async {
    final User? currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Você precisa estar logado para excluir categorias.')),
      );
      return;
    }

    // 1. Verificar se existem transações associadas a esta categoria
    try {
      final List<dynamic> transactionsCount = await supabase
          .from('transacoes')
          .select('id')
          .eq('user_id', currentUser.id)
          .eq('categoria_id', categoryId)
          .limit(1);

      if (transactionsCount.isNotEmpty) {
        final bool? confirmReassign = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Categoria em Uso'),
              content: const Text(
                'Esta categoria possui transações associadas a ela. Para excluí-la, você deve primeiro reatribuir ou excluir as transações que a utilizam.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Ok'),
                ),
              ],
            );
          },
        );
        if (confirmReassign == null || !confirmReassign) {
          return; // Aborta a exclusão se o usuário não confirmou
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao verificar transações: $e')),
      );
      print('Erro ao verificar transações antes da exclusão: $e');
      return;
    }

    // 2. Confirmação de exclusão da categoria
    final bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: const Text(
              'Tem certeza que deseja excluir esta categoria? Esta ação é irreversível.'),
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
            .from('categorias')
            .delete()
            .eq('id', categoryId)
            .eq('user_id', currentUser.id);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Categoria excluída com sucesso!')),
        );
        setState(() {
          _categoriasFuture = _fetchCategories(); // Recarrega a lista
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir categoria: $e')),
        );
        print('Erro ao excluir categoria: $e');
        setState(() {
          _categoriasFuture =
              _fetchCategories(); // Tenta recarregar mesmo com erro
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Categorias'),
      ),
      body: FutureBuilder<List<Categoria>>(
        future: _categoriasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Erro: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma categoria encontrada.\nClique no "+" para adicionar uma!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          } else {
            final List<Categoria> categorias = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: categorias.length,
              itemBuilder: (context, index) {
                final categoria = categorias[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    title: Text(categoria.nome),
                    subtitle: Text(
                        'Tipo: ${categoria.tipo == 'receita' ? 'Receita' : 'Despesa'}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            _editCategory(
                                categoria); // Chama a função de edição
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            _deleteCategory(
                                categoria.id); // Chama a função de exclusão
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _categoryNameController.clear(); // Limpa antes de mostrar o diálogo
          _selectedCategoryType = 'despesa'; // Reseta o tipo padrão
          showDialog(
            context: context,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                title: const Text('Adicionar Nova Categoria'),
                content: StatefulBuilder(
                  // Usa StatefulBuilder para atualizar o dropdown no diálogo
                  builder:
                      (BuildContext context, StateSetter setStateInDialog) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _categoryNameController,
                          decoration: const InputDecoration(
                              labelText: 'Nome da Categoria'),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: _selectedCategoryType,
                          decoration: const InputDecoration(labelText: 'Tipo'),
                          items: const [
                            DropdownMenuItem(
                                value: 'receita', child: Text('Receita')),
                            DropdownMenuItem(
                                value: 'despesa', child: Text('Despesa')),
                          ],
                          onChanged: (String? newValue) {
                            setStateInDialog(() {
                              // Atualiza o estado do diálogo
                              _selectedCategoryType = newValue!;
                            });
                          },
                        ),
                      ],
                    );
                  },
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: _addCategory,
                    child: const Text('Adicionar'),
                  ),
                ],
              );
            },
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
