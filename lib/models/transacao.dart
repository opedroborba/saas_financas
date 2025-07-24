import 'package:intl/intl.dart';

class Transacao {
  final String id;
  final String userId;
  final String descricao;
  final double valor;
  final DateTime data;
  final String tipo; // 'receita' ou 'despesa'
  final String? categoriaId; // Pode ser nulo se não houver categoria

  Transacao({
    required this.id,
    required this.userId,
    required this.descricao,
    required this.valor,
    required this.data,
    required this.tipo,
    this.categoriaId,
  });

  factory Transacao.fromJson(Map<String, dynamic> json) {
    return Transacao(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      descricao: json['descricao'] as String,
      valor: (json['valor'] as num).toDouble(),
      data: DateTime.parse(json['data'] as String),
      tipo: json['tipo'] as String,
      categoriaId: json['categoria_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'descricao': descricao,
      'valor': valor,
      'data': DateFormat('yyyy-MM-dd').format(data),
      'tipo': tipo,
      'categoria_id': categoriaId,
    };
  }
}
