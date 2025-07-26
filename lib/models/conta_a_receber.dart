import 'package:intl/intl.dart';

class ContaAReceber {
  final String id;
  final String userId;
  final String descricao;
  final double valor;
  final DateTime dataRecebimentoPrevista; // Data prevista para recebimento
  final String categoriaId;
  final String tipo; // Será sempre 'receita' para Contas a Receber
  final String status; // 'pendente', 'recebida', 'cancelada'
  final DateTime? dataCriacao; // Opcional
  final String? categoriaNome; // Para exibição, não armazenado no banco

  ContaAReceber({
    required this.id,
    required this.userId,
    required this.descricao,
    required this.valor,
    required this.dataRecebimentoPrevista,
    required this.categoriaId,
    this.tipo = 'receita', // Valor padrão
    this.status = 'pendente', // Valor padrão
    this.dataCriacao,
    this.categoriaNome,
  });

  factory ContaAReceber.fromJson(Map<String, dynamic> json) {
    return ContaAReceber(
      id: json['id'],
      userId: json['user_id'],
      descricao: json['descricao'],
      valor: (json['valor'] as num).toDouble(),
      dataRecebimentoPrevista:
          DateTime.parse(json['data_recebimento_prevista']),
      categoriaId: json['categoria_id'],
      tipo: json['tipo'] ?? 'receita',
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
      'data_recebimento_prevista':
          DateFormat('yyyy-MM-dd').format(dataRecebimentoPrevista),
      'categoria_id': categoriaId,
      'tipo': tipo,
      'status': status,
      'data_criacao': dataCriacao != null
          ? '${DateFormat('yyyy-MM-ddTHH:mm:ss').format(dataCriacao!)}Z' // UTC
          : null,
    };
  }
}
