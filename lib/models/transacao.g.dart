// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transacao.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Transacao _$TransacaoFromJson(Map<String, dynamic> json) => Transacao(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      descricao: json['descricao'] as String,
      valor: (json['valor'] as num).toDouble(),
      tipo: json['tipo'] as String,
      data: DateTime.parse(json['data'] as String),
      categoriaId: json['categoria_id'] as String?,
    );

Map<String, dynamic> _$TransacaoToJson(Transacao instance) => <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'descricao': instance.descricao,
      'valor': instance.valor,
      'tipo': instance.tipo,
      'data': instance.data.toIso8601String(),
      'categoria_id': instance.categoriaId,
    };
