import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gabarito_plus/features/aluno/data/aluno.dart';
import 'package:gabarito_plus/features/correcao_prova/services/correcao_repository.dart';
import 'package:gabarito_plus/features/disciplina/data/assunto.dart';
import 'package:gabarito_plus/features/geracao_prova/data/correcao.dart';
import 'package:gabarito_plus/features/geracao_prova/data/embaralhador.dart';
import 'package:gabarito_plus/features/geracao_prova/data/prova.dart';
import 'package:gabarito_plus/features/geracao_prova/service/prova_repository.dart';
import 'package:gabarito_plus/features/geracao_prova/ui/consulta_provas_geradas.dart';
import 'package:gabarito_plus/features/geracao_prova/ui/detalhes_prova_gerada.dart';
import 'package:gabarito_plus/features/questoes/data/alternativa.dart';
import 'package:gabarito_plus/features/questoes/data/questao.dart';
import 'package:gabarito_plus/features/turma/data/turma.dart';

import 'helpers/correcao_repository_memoria.dart';
import 'helpers/prova_repository_memoria.dart';

Questao questao(String id) => Questao(
      id: id,
      enunciado: 'Enunciado $id',
      alternativas: [
        for (var i = 0; i < 4; i++) Alternativa(texto: 'Alt $i', isCorreta: i == 0),
      ],
    );

Aluno aluno(String nome) =>
    Aluno(id: 'id-$nome', nome: nome, email: '', isAtivo: true);

Prova prova({
  String id = 'K7Q2XM',
  String titulo = 'Prova de Soma',
  String nomeTurma = '3º Ano A',
  List<String> alunos = const ['Ana', 'Bruno', 'Carla'],
  List<String> questoes = const ['q1', 'q2'],
}) =>
    Prova(
      id: id,
      titulo: titulo,
      turma: Turma(
        id: 'turma-$nomeTurma',
        nomeTurma: nomeTurma,
        listaAlunos: alunos.map(aluno).toList(),
        ativa: true,
      ),
      assunto: Assunto(id: 'assunto-1', nome: 'Soma', questoes: const []),
      questoes: questoes.map(questao).toList(),
      embaralharQuestoes: true,
      embaralharAlternativas: true,
    );

Correcao correcao(String codigo, {String titulo = 'Prova de Soma'}) => Correcao(
      codigoVersao: codigo,
      tituloProva: titulo,
      nomeTurma: '3º Ano A',
      nomeAluno: 'Ana',
      respostas: const [],
      quantidadeAlternativas: 4,
      dataHora: DateTime(2026, 11, 10),
    );

void main() {
  late CorrecaoRepositoryMemoria correcoes;
  late ProvaRepositoryMemoria provas;

  Future<void> salvar(Prova p) => provas.salvar(p, Embaralhador.gerarVersoes(p));

  setUp(() {
    correcoes = CorrecaoRepositoryMemoria();
    provas = ProvaRepositoryMemoria(correcoes: correcoes);
    CorrecaoRepository.instancia = correcoes;
    ProvaRepository.instancia = provas;
  });

  group('ProvaSalva.fromMap', () {
    test('lê o formato gravado por Prova.toMap, com as datas', () {
      final criada = DateTime(2026, 11, 1, 8);
      final salva = ProvaSalva.fromMap('K7Q2XM', {
        ...prova().toMap(),
        'criadaEm': Timestamp.fromDate(criada),
      });

      expect(salva.id, 'K7Q2XM');
      expect(salva.titulo, 'Prova de Soma');
      expect(salva.nomeTurma, '3º Ano A');
      expect(salva.nomeAssunto, 'Soma');
      expect(salva.questoesIds, ['q1', 'q2']);
      expect(salva.embaralharQuestoes, isTrue);
      expect(salva.criadaEm, criada);
      expect(salva.editadaEm, isNull);
    });

    test('toMap da edição não sobrescreve criadaEm', () {
      final mapa = prova().toMap(edicao: true);
      expect(mapa.containsKey('criadaEm'), isFalse);
      expect(mapa.containsKey('editadaEm'), isTrue);
    });
  });

  group('ProvaRepository (memória): consulta e edição', () {
    test('lista as provas e as versões em ordem de código', () async {
      await salvar(prova());

      final lista = await provas.listar();
      expect(lista.single.id, 'K7Q2XM');

      final versoes = await provas.listarVersoes('K7Q2XM');
      expect(versoes.map((v) => v.codigo), ['K7Q2XM-01', 'K7Q2XM-02', 'K7Q2XM-03']);
    });

    test('atualizar o título também troca nas correções da prova', () async {
      await salvar(prova());
      await correcoes.salvar(correcao('K7Q2XM-01'));
      await correcoes.salvar(correcao('OUTRA1-01', titulo: 'Outra'));

      await provas.atualizarTitulo('K7Q2XM', 'Soma - 2º bimestre');

      expect((await provas.buscar('K7Q2XM'))!.titulo, 'Soma - 2º bimestre');
      expect((await correcoes.obterPorCodigo('K7Q2XM-01'))!.tituloProva,
          'Soma - 2º bimestre');
      expect((await correcoes.obterPorCodigo('OUTRA1-01'))!.tituloProva, 'Outra');
    });

    test('substituir mantém os códigos e apaga as versões que sobraram',
        () async {
      await salvar(prova());

      final editada = prova(alunos: ['Ana', 'Bruno'], questoes: ['q1', 'q2', 'q3']);
      await provas.substituir(editada, Embaralhador.gerarVersoes(editada));

      final versoes = await provas.listarVersoes('K7Q2XM');
      expect(versoes.map((v) => v.codigo), ['K7Q2XM-01', 'K7Q2XM-02']);
      expect(versoes.first.questoes, hasLength(3));
      expect((await provas.buscar('K7Q2XM'))!.questoesIds, ['q1', 'q2', 'q3']);
      // o gabarito lido pela câmera já é o novo
      expect((await provas.buscarGabarito('K7Q2XM-01'))!.totalQuestoes, 3);
      expect(await provas.buscarGabarito('K7Q2XM-03'), isNull);
    });

    test('com correções, substituir e excluir são recusados', () async {
      final p = prova();
      await salvar(p);
      await correcoes.salvar(correcao('K7Q2XM-02'));

      await expectLater(
        provas.substituir(p, Embaralhador.gerarVersoes(p)),
        throwsStateError,
      );
      await expectLater(provas.excluir('K7Q2XM'), throwsStateError);
      expect(await provas.buscar('K7Q2XM'), isNotNull);
    });

    test('sem correções, excluir apaga a prova e as versões', () async {
      await salvar(prova());

      await provas.excluir('K7Q2XM');

      expect(await provas.buscar('K7Q2XM'), isNull);
      expect(await provas.listarVersoes('K7Q2XM'), isEmpty);
    });

    test('contarPorProva usa o prefixo do código, sem confundir provas',
        () async {
      await correcoes.salvar(correcao('K7Q2XM-01'));
      await correcoes.salvar(correcao('K7Q2XM-02'));
      await correcoes.salvar(correcao('K7Q2XMA-01'));

      expect(await correcoes.contarPorProva('K7Q2XM'), 2);
    });
  });

  group('ConsultaProvasGeradasView', () {
    Future<void> abrirConsulta(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: ConsultaProvasGeradasView()));
      await tester.pumpAndSettle();
    }

    testWidgets('o card mostra só título e código', (tester) async {
      await salvar(prova());
      await salvar(prova(id: 'ABC234', titulo: 'Prova de Frações', nomeTurma: '2º Ano B'));

      await abrirConsulta(tester);

      expect(find.text('Prova de Soma'), findsOneWidget);
      expect(find.text('K7Q2XM'), findsOneWidget);
      expect(find.text('Prova de Frações'), findsOneWidget);
      expect(find.text('ABC234'), findsOneWidget);
      // turma não aparece no card, só no filtro
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('card-prova-ABC234')),
          matching: find.text('2º Ano B'),
        ),
        findsNothing,
      );
    });

    testWidgets('filtra por turma', (tester) async {
      await salvar(prova());
      await salvar(prova(id: 'ABC234', titulo: 'Prova de Frações', nomeTurma: '2º Ano B'));

      await abrirConsulta(tester);
      await tester.tap(find.text('Todas as turmas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2º Ano B').last);
      await tester.pumpAndSettle();

      expect(find.text('Prova de Frações'), findsOneWidget);
      expect(find.text('Prova de Soma'), findsNothing);
    });

    testWidgets('filtra por título ou código', (tester) async {
      await salvar(prova());
      await salvar(prova(id: 'ABC234', titulo: 'Prova de Frações'));

      await abrirConsulta(tester);
      await tester.enterText(find.byType(TextField), 'abc2');
      await tester.pumpAndSettle();

      expect(find.text('Prova de Frações'), findsOneWidget);
      expect(find.text('Prova de Soma'), findsNothing);
    });

    testWidgets('mostra o estado vazio', (tester) async {
      await abrirConsulta(tester);
      expect(find.text('Nenhuma prova gerada até o momento.'), findsOneWidget);
    });
  });

  group('DetalhesProvaGeradaView', () {
    Future<void> abrirDetalhe(WidgetTester tester) async {
      final salva = (await provas.buscar('K7Q2XM'))!;
      await tester.pumpWidget(
        MaterialApp(home: DetalhesProvaGeradaView(prova: salva)),
      );
      await tester.pumpAndSettle();
    }

    IconButton botao(WidgetTester tester, IconData icone) => tester.widget(
          find.ancestor(of: find.byIcon(icone), matching: find.byType(IconButton)),
        );

    testWidgets('mostra as versões e libera editar e excluir sem correções',
        (tester) async {
      await salvar(prova());
      await abrirDetalhe(tester);

      expect(find.text('Código da versão: K7Q2XM-01'), findsOneWidget);
      expect(find.text('Código da versão: K7Q2XM-03'), findsOneWidget);
      expect(botao(tester, Icons.edit).onPressed, isNotNull);
      expect(botao(tester, Icons.delete_outline).onPressed, isNotNull);
    });

    testWidgets('com correções, editar e excluir avisam e não seguem',
        (tester) async {
      await salvar(prova());
      await correcoes.salvar(correcao('K7Q2XM-01'));
      await abrirDetalhe(tester);

      // sem faixa de aviso na tela
      expect(find.textContaining('só o título pode ser alterado'), findsNothing);

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pumpAndSettle();
      expect(find.text('Prova já corrigida'), findsOneWidget);
      expect(find.textContaining('Não é possível editar'), findsOneWidget);
      await tester.tap(find.text('Entendi'));
      await tester.pumpAndSettle();
      expect(find.text('Editar Prova'), findsNothing);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.textContaining('Não é possível excluir'), findsOneWidget);
      await tester.tap(find.text('Entendi'));
      await tester.pumpAndSettle();
      expect(await provas.buscar('K7Q2XM'), isNotNull);
    });

    testWidgets('o resumo da prova começa fechado e abre ao tocar',
        (tester) async {
      await salvar(prova());
      await abrirDetalhe(tester);

      expect(find.text('Código: K7Q2XM'), findsNothing);
      await tester.tap(find.text('Prova de Soma'));
      await tester.pumpAndSettle();
      expect(find.text('Código: K7Q2XM'), findsOneWidget);
    });

    testWidgets('edita o título pelo diálogo', (tester) async {
      await salvar(prova());
      await abrirDetalhe(tester);

      await tester.tap(find.byIcon(Icons.title));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextFormField)),
        'Soma revisada',
      );
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Soma revisada'), findsOneWidget);
      expect((await provas.buscar('K7Q2XM'))!.titulo, 'Soma revisada');
    });

    testWidgets('exclui a prova depois de confirmar', (tester) async {
      await salvar(prova());
      await abrirDetalhe(tester);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
      await tester.pumpAndSettle();

      expect(await provas.buscar('K7Q2XM'), isNull);
    });
  });
}
