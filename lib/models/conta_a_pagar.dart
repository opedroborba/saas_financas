import 'package:intl/intl.dart';

class ContaAPagar {
  final String id;
  final String userId;
  final String descricao;
  final double valor;
  final DateTime dataVencimento; // Data prevista para pagamento
  final String categoriaId;
  final String tipo; // Será sempre 'despesa' para Contas a Pagar
  final String status; // 'pendente', 'paga', 'cancelada'
  final DateTime? dataCriacao; // Opcional
  final String? categoriaNome; // Para exibição, não armazenado no banco

  ContaAPagar({
    required this.id,
    required this.userId,
    required this.descricao,
    required this.valor,
    required this.dataVencimento,
    required this.categoriaId,
    this.tipo = 'despesa', // Valor padrão
    this.status = 'pendente', // Valor padrão
    this.dataCriacao,
    this.categoriaNome,
  });

  factory ContaAPagar.fromJson(Map<String, dynamic> json) {
    return ContaAPagar(
      id: json['id'],
      userId: json['user_id'],
      descricao: json['descricao'],
      valor: (json['valor'] as num).toDouble(),
      dataVencimento: DateTime.parse(json['data_vencimento']),
      categoriaId: json['categoria_id'],
      tipo: json['tipo'] ?? 'despesa',
      status: json['status'] ?? 'pendente',
      dataCriacao: json['data_criacao'] != null
          ? DateTime.parse(json['data_criacao'])
          : null,
      // Para o nome da categoria, que virá do join na consulta
      categoriaNome:
          (json['categorias'] != null && json['categorias']['nome'] != null)
              ? json['categorias']['nome'] as String
              : 'Sem Categoria',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'descricao': descricao,
      'valor': valor,
      'data_vencimento': DateFormat('yyyy-MM-dd').format(dataVencimento),
      'categoria_id': categoriaId,
      'tipo': tipo,
      'status': status,
      'data_criacao': dataCriacao != null
          ? '${DateFormat('yyyy-MM-ddTHH:mm:ss').format(dataCriacao!)}Z' // UTC
          : null,
    };
  }
}
