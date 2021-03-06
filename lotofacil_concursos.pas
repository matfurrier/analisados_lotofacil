unit lotofacil_concursos;

{$mode objfpc}{$H+}

interface

uses
    Classes, SysUtils, ZConnection, ZDataset, Dialogs, StdCtrls, lotofacil_constantes, Grids, IdHTTP,
    fpjson, strUtils, dateutils, IdGlobal, variants, lotofacil_var_global;

type
    TArrayInt = array of integer;
    TArrayByte = array of Byte;
    TConcurso_Asc_Desc = (CONCURSO_ASC, CONCURSO_DESC);
    TConcursos_ja_inseridos_opcao = record
      concurso_ordem_asc_desc : TConcurso_Asc_Desc;
    end;

function obter_concursos(sql_conexao: TZConnection; var lista_de_concursos: TArrayInt; ordem_asc: string): boolean;

function obter_bolas_do_concurso(sql_conexao: TZConnection; concurso: integer;
    var bolas_do_concurso: TArrayInt): boolean;

function obter_zero_um_das_bolas_no_intervalo_de_concursos(sql_conexao: TZConnection;
    var concursos_no_intervalo: TLotofacil_Concurso_Array;
    concurso_inicial: Integer; concurso_final: Integer; ordem_asc_desc: String): boolean;

function obter_concursos_no_intervalo(
  sql_conexao: TZConnection; var concursos_no_intervalo: TLotofacil_Concurso_Array;
  concurso_inicial: Integer; concurso_final: Integer; ordem_asc_desc: String
  ): boolean;

function preencher_combinacoes_com_todos_os_concursos(sql_conexao: TZConnection; sgr_controle: TStringGrid; ordem_asc_desc: String):boolean;
function preencher_combinacoes_intervalo_de_concursos(
    sql_conexao: TZConnection; sgr_controle: TStringGrid; ordem_asc_desc: String;
    concurso_inicial: Integer; concurso_final:Integer): boolean;

function concurso_excluir(sql_conexao: TZConnection; concurso_numero: integer; status_erro: string): boolean;
procedure preencher_combobox_com_concursos(sql_conexao: TZConnection; cmb_controle: TComboBox; ordem_asc: string);
procedure baixar_novos_concursos(sql_conexao: TZConnection; sgr_controle: TStringGrid);
procedure exibir_concursos_importados(sql_conexao: TZConnection; sgr_controle: TStringGrid);
function gerar_sql_dinamicamente(lista_de_resultado_json: TStringList): string;

//procedure atualizar_controle_de_concursos(sql_conexao: TZConnection; cmb_controle: TComboBox);

function Obter_todos_os_concursos(sql_conexao: TZConnection; var lista_de_concursos: TStringList): boolean;

implementation

{
 Retorna true, se obter pelo menos um concurso, falso caso contr??rio.
}
function Obter_todos_os_concursos(sql_conexao: TZConnection; var lista_de_concursos: TStringList): boolean;
var
    sql_query: TZQuery;
begin

    if not Assigned(lista_de_concursos) then
    begin
        lista_de_concursos := TStringList.Create;
    end;
    //lista_de_concursos.Clear;

    //if not Assigned(dmLotofacil) then
    //begin
    //    dmLotofacil := TdmLotofacil.Create(nil);
    //end;

    try
        sql_query := TZQuery.Create(nil);
        sql_query.Connection := sql_conexao;

        //sql_query := dmLotofacil.sqlLotofacil;
        //sql_query.DataBase := dmLotofacil.pgLTK;
        //sql_query.UniDirectional:= false;
        sql_query.Sql.Clear;

        sql_query.Sql.Add('Select concurso from lotofacil.v_lotofacil_concursos');
        sql_query.Sql.Add('order by concurso');

        sql_query.Open;
        sql_query.First;
        lista_de_concursos.Clear;
        while not sql_query.EOF do
        begin
            lista_de_concursos.Add(IntToStr(sql_query.FieldByName('concurso').AsInteger));
            sql_query.Next;
        end;
        sql_query.Close;

    except
        On Exc: Exception do
        begin
            lista_de_concursos.Clear;
            FreeAndNil(lista_de_concursos);
            Exit(False);
        end;
    end;

    //FreeAndNil(dmLotofacil);
    FreeAndNil(sql_query);

    if lista_de_concursos.Count <> 0 then
    begin
        Exit(True);
    end
    else
    begin
        Exit(False);
    end;
end;

{
 Retorna as bolas do concurso, se o n??mero do concurso foi localizado
 na tabela 'lotofacil.lotofacil_resultado_bolas'.
 Se o concurso existe, a fun????o retorna true, falso, caso contr??rio.
 A vari??vel 'bolas_do_concurso' retorna um arranjo com 16 posi????es, entretanto,
 retornamos 15 bolas, come??ando da posi????o 1.
}
function obter_bolas_do_concurso(sql_conexao: TZConnection; concurso: integer;
    var bolas_do_concurso: TArrayInt): boolean;
var
    sql_query: TZQuery;
    uA: integer;
begin

    sql_query := TZQuery.Create(nil);
    sql_query.Connection := sql_conexao;
    sql_query.Sql.Clear;
    sql_query.Sql.Add('Select * from lotofacil.lotofacil_resultado_bolas');
    sql_query.Sql.Add('where concurso = ' + IntToStr(concurso));
    sql_query.Open;

    if sql_query.RecordCount <= 0 then
    begin
        bolas_do_concurso := nil;
        Exit(False);
    end;

    // H?? 15 bolas, iremos criar um arranjo com 16 bolas, iremos
    // usar ??ndices de 1 a 15.
    SetLength(bolas_do_concurso, 16);

    sql_query.First;

    for uA := 1 to 15 do
    begin
        bolas_do_concurso[uA] := sql_query.FieldByName('b_' + IntToStr(uA)).AsInteger;
    end;

    sql_query.Close;
    FreeAndNil(sql_query);

    Exit(True);
end;

{
 Retorna todos os concursos no intervalo definido do usu??rio, os concursos
 s??o retornados da tabela lotofacil_resultado_num, neste tabela, cada bola
 tem um campo de prefixo 'num_', que serve pra identificar qual campo estamos.
 Em cada campo, h?? o valor '0', se a bola n??o faz parte da combina????o ou
 '1', se a bola faz parte da combina????o do concurso atual.
 Se precisamos comparar duas combina????es, a maneira mas r??pida ?? percorrer
 cada bola e comparando com a outra.
}
function obter_zero_um_das_bolas_no_intervalo_de_concursos(
  sql_conexao: TZConnection; var concursos_no_intervalo: TLotofacil_Concurso_Array;
  concurso_inicial: Integer; concurso_final: Integer; ordem_asc_desc: String
  ): boolean;
var
  sql_query: TZQuery;
  id_registro, uA: Integer;
  qt_registros, bola_atual, valor_zero_um_do_campo: LongInt;
begin
    ordem_asc_desc := LowerCase(ordem_asc_desc);
    if (ordem_asc_desc <> 'desc') and (ordem_asc_desc <> 'asc') then begin
        ordem_asc_desc := 'asc';
    end;

    TRY
       sql_query := TZQuery.Create(NIl);
       sql_query.Connection := sql_conexao;
       sql_query.Sql.Clear;
       sql_query.Sql.Add('Select * from lotofacil.lotofacil_resultado_num');
       sql_query.Sql.Add('where concurso >= ' + IntToStr(concurso_inicial));
       sql_query.Sql.Add('and concurso <= ' + IntToStr(concurso_final));
       sql_query.Sql.Add('order by concurso ' + ordem_asc_desc);
       sql_query.Open;

       sql_query.First;
       sql_query.Last;
       qt_registros := sql_query.RecordCount;
       if qt_registros = 0 then begin
           FreeAndNil(sql_query);
           SetLength(concursos_no_intervalo, 0);
           Exit(False);
       end;

       SetLength(concursos_no_intervalo, qt_registros);
       if Length(concursos_no_intervalo) <= 0 then begin
           Exception.Create('N??o foi poss??vel alocar mem??ria pra o arranjo.');
           Exit(False);
       end;

       id_registro := 0;
       sql_query.First;
       while Not Sql_query.EOF do begin
           concursos_no_intervalo[id_registro].concurso:= sql_query.FieldByName('concurso').AsInteger;
           for uA := 1 to 25 do begin
               valor_zero_um_do_campo := sql_query.FieldByName('num_' + IntToStr(uA)).AsInteger;
               concursos_no_intervalo[id_registro].num1_a_num_25[uA] := valor_zero_um_do_campo;
           end;
           sql_query.Next;
           Inc(id_registro);
       end;
       FreeAndNil(sql_query);
    EXCEPT
        On exc: Exception do begin
           MessageDlg('', 'Erro: ' + Exc.Message, mtError, [mbok], 0);
           Exit(False);
        end;
    end;
    Exit(True);
end;

{
 Obt??m todas as informa????es das bolas, nas posi????es 'b_1' a 'b_15' e os valores '0' ou '1'
 nos campos 'num_1' a 'num_25' referente a um ou v??rios concursos no intervalo especificado.
 Praticamente, aqui, temos todas as informa????es necess??rias, que podem ser utilizadas
 em outras fun????es.
 Ao inv??s de ter v??rios fun????es que obt??m informa????es espec??ficas, aqui, obtemos tudo
 que precisamos saber sobre os concursos j?? sorteados.
}
function obter_concursos_no_intervalo(
  sql_conexao: TZConnection; var concursos_no_intervalo: TLotofacil_Concurso_Array;
  concurso_inicial: Integer; concurso_final: Integer; ordem_asc_desc: String
  ): boolean;
var
  sql_query: TZQuery;
  id_registro, uA, indice_bola_b1_a_b15: Integer;
  qt_registros, bola_atual, valor_zero_um_do_campo: LongInt;
begin
    ordem_asc_desc := LowerCase(ordem_asc_desc);
    if (ordem_asc_desc <> 'desc') and (ordem_asc_desc <> 'asc') then begin
        ordem_asc_desc := 'asc';
    end;

    TRY
       sql_query := TZQuery.Create(NIl);
       sql_query.Connection := sql_conexao;
       sql_query.Sql.Clear;
       sql_query.Sql.Add('Select * from lotofacil.lotofacil_resultado_num');
       sql_query.Sql.Add('where concurso >= ' + IntToStr(concurso_inicial));
       sql_query.Sql.Add('and concurso <= ' + IntToStr(concurso_final));
       sql_query.Sql.Add('order by concurso ' + ordem_asc_desc);
       sql_query.Open;

       sql_query.First;
       sql_query.Last;
       qt_registros := sql_query.RecordCount;
       if qt_registros = 0 then begin
           FreeAndNil(sql_query);
           SetLength(concursos_no_intervalo, 0);
           Exit(False);
       end;

       SetLength(concursos_no_intervalo, qt_registros);
       if Length(concursos_no_intervalo) <= 0 then begin
           Exception.Create('N??o foi poss??vel alocar mem??ria pra o arranjo.');
           Exit(False);
       end;

       id_registro := 0;
       sql_query.First;
       while Not Sql_query.EOF do begin
           concursos_no_intervalo[id_registro].concurso:= sql_query.FieldByName('concurso').AsInteger;
           indice_bola_b1_a_b15 := 1;
           for uA := 1 to 25 do begin
               valor_zero_um_do_campo := sql_query.FieldByName('num_' + IntToStr(uA)).AsInteger;
               concursos_no_intervalo[id_registro].num1_a_num_25[uA] := valor_zero_um_do_campo;
               // Se o valor do campo ?? 1, quer dizer que a bola faz parte da combina????o, ent??o,
               // iremos preencher o arranjo 'b1_a_b15', com a bola correspondente na posi????o.
               if valor_zero_um_do_campo = 1 then begin
                   concursos_no_intervalo[id_registro].b1_a_b15[indice_bola_b1_a_b15] := uA;
                   Inc(indice_bola_b1_a_b15);
               end;
           end;
           sql_query.Next;
           Inc(id_registro);
       end;
       FreeAndNil(sql_query);
    EXCEPT
        On exc: Exception do begin
           MessageDlg('', 'Erro: ' + Exc.Message, mtError, [mbok], 0);
           Exit(False);
        end;
    end;
    Exit(True);
end;

{
 Preenche um controle 'TStringGrid', com todas as combina????es j?? sorteadas da lotofacil.
}
function preencher_combinacoes_com_todos_os_concursos(sql_conexao: TZConnection;
  sgr_controle: TStringGrid; ordem_asc_desc: String): boolean;
var
  sql_query: TZQuery;
  coluna_atual: TGridColumn;
  concurso_numero, bola_atual, qt_registros: LongInt;
  sgr_controle_linha, uA: Integer;
begin
    ordem_asc_desc := LowerCase(ordem_asc_desc);
    if (ordem_asc_desc <> 'asc') and (ordem_asc_desc <> 'desc') then begin
        Exit(False);
    end;

    try

      sql_query := TZQuery.Create(Nil);
      sql_query.Connection := sql_conexao;
      sql_query.SQL.Clear;
      sql_query.Sql.Add('Select concurso');
      sql_query.Sql.Add(',b_1,b_2,b_3,b_4,b_5,b_6,b_7,b_8,b_9,b_10,b_11,b_12,b_13,b_14,b_15');
      sql_query.Sql.Add('from lotofacil.lotofacil_resultado_bolas');
      sql_query.Sql.Add('order by concurso');
      sql_query.Sql.Add(ordem_asc_desc);
      sql_query.Open;
      sql_query.First;
      sql_query.Last;

      qt_registros := sql_query.RecordCount;
      if qt_registros = 0 then begin
          FreeAndNil(sql_query);
          Exit(False);
      end;

      // Configura o controle
      sgr_controle.Columns.Clear;
      // Haver?? uma linha pra o cabe??alho.
      sgr_controle.RowCount := qt_registros + 1;

      // Aqui, iremos configurar os nomes dos t??tulos das colunas
      // por isso, precisamos definir 1 (uma) linha fixa no controle.
      sgr_controle.FixedRows:=1;
      for uA := 0 to 15 do begin
          coluna_atual := sgr_controle.Columns.Add;
          if uA = 0 then begin
             coluna_atual.Title.Caption := 'Concurso'
          end else begin
            coluna_atual.Title.Caption := 'B' + IntToStr(uA);
          end;
      end;

      // Agora iremos popular os dados da consulta.
      sgr_controle_linha := 1;
      sql_query.First;
      sgr_controle.BeginUpdate;
      while (Not sql_query.Eof) and (qt_registros > 0) do begin
          concurso_numero := sql_query.FieldByName('concurso').AsInteger;
          sgr_controle.Cells[0, sgr_controle_linha] := IntToStr(concurso_numero);
          for uA := 1 to 15 do begin
              bola_atual := sql_query.FieldByName('b_' + IntToStr(uA)).AsInteger;
              sgr_controle.Cells[uA, sgr_controle_linha] := IntToStr(bola_atual);
          end;
          Inc(sgr_controle_linha);
          sql_query.Next;
          Dec(qt_registros);
      end;
      sgr_controle.AutoAdjustColumns;
      sgr_controle.EndUpdate(true);
      FreeAndNil(sql_query);

    Except
        On Exc: Exception do begin
            FreeAndNil(sql_query);
            MessageDlg('', 'Erro: ' + Exc.Message, mtError, [mbok], 0);
            Exit(False);
        end;
    end;

    Exit(True);
end;

function preencher_combinacoes_intervalo_de_concursos(
  sql_conexao: TZConnection; sgr_controle: TStringGrid; ordem_asc_desc: String;
  concurso_inicial: Integer; concurso_final: Integer): boolean;
begin

end;

{
 Retorna true, se o concurso foi exclu??do com sucesso da tabela no banco de dados.
 Se houver erro, false ?? retorna, e o par??metro status_erro indica a mensagem de erro.
}
function concurso_excluir(sql_conexao: TZConnection; concurso_numero: integer; status_erro: string): boolean;
var
    sql_query: TZQuery;
begin
    try
        sql_query := TZQuery.Create(nil);
        sql_query.Connection := sql_conexao;
        sql_query.Connection.Connected := False;
        sql_query.Connection.AutoCommit := False;

        sql_query.Sql.Add('Delete from lotofacil.lotofacil_resultado_num');
        sql_query.Sql.Add('where concurso =');
        sql_query.Sql.Add(IntToStr(concurso_numero));
        sql_query.ExecSql;
        sql_query.Connection.Commit;
        sql_query.Close;
        sql_query.Connection.Connected := False;
        FreeAndNil(sql_query);

    except
        On Exc: Exception do
        begin
            status_erro := Exc.Message;
            Exit(False);
        end;

    end;
    Exit(True);
end;

{
 Preenche um controle do tipo caixa de combina????o com todos os concursos
 em ordem crescente ou decrescente.
}
procedure preencher_combobox_com_concursos(sql_conexao: TZConnection; cmb_controle: TComboBox; ordem_asc: string);
var
    uA: integer;
    lista_de_concursos: TArrayInt;
begin
    cmb_controle.Items.Clear;
    if not obter_concursos(sql_conexao, lista_de_concursos, ordem_asc) then
    begin
        Exit;
    end;
    for uA := 0 to High(lista_de_concursos) do
    begin
        cmb_controle.Items.Add(IntToStr(lista_de_concursos[uA]));
    end;
    cmb_controle.ItemIndex := 0;
end;

{
 Retorna todos os concursos, em ordem ascendente ou descente.
 A fun????o retorna true, se h?? concursos, falso, caso contr??rio.
}
function obter_concursos(sql_conexao: TZConnection; var lista_de_concursos: TArrayInt; ordem_asc: string): boolean;
var
    sql_query: TZQuery;
    uA: integer;
    qt_registros: longint;
begin
    ordem_asc := LowerCase(ordem_asc);
    if (ordem_asc <> 'asc') and (ordem_asc <> 'desc') then
    begin
        ordem_asc := 'desc';
    end;

    try
        sql_query := TZQuery.Create(nil);
        sql_query.Connection := sql_conexao;
        sql_query.Connection.Connected := False;
        sql_query.Sql.Clear;
        sql_query.Sql.Add('Select concurso from lotofacil.lotofacil_resultado_bolas');
        sql_query.Sql.Add('order by concurso');
        sql_query.Sql.Add(ordem_asc);
        sql_query.Open;
        sql_query.First;
        sql_query.Last;
        qt_registros := sql_query.RecordCount;

        if qt_registros <= 0 then
        begin
            sql_query.Close;
            sql_query.Connection.Connected := False;
            SetLength(lista_de_concursos, 0);
            Exit(False);
        end;

        SetLength(lista_de_concursos, qt_registros);
        sql_query.First;
        for uA := 0 to Pred(qt_registros) do
        begin
            lista_de_concursos[uA] := sql_query.FieldByName('concurso').AsInteger;
            sql_query.Next;
        end;

        sql_query.Close;
        sql_query.Connection.Connected := False;
        FreeAndNil(sql_query);

    except
        On Exc: Exception do
        begin
            MessageDlg('', 'Erro: ' + Exc.Message, mtError, [mbOK], 0);
            Exit(False);
        end;
    end;

    Exit(True);
end;

{
 A procedure abaixo, conecta no site da caixa, em seguida, pega o ??ltimo concurso
 sorteado, em seguida, de posse deste n??mero, gera v??rias urls do ??ltimo concurso ao
 primeiro concurso, em seguida, baixa o json de cada url, em seguida, analisa cada json
 e insere tais dados analisados na tabela 'd_sorte_resultado_importacao'.
 }
procedure baixar_novos_concursos(sql_conexao: TZConnection; sgr_controle: TStringGrid);
var
    ultimo_concurso, uA: integer;
    obj_http:   TIdHTTP;
    url_lotofacil, conteudo_recebido, sql_gerado: string;
    request:    TIdHTTPRequest;
    resultado_json: TJSONData;
    json_chave_valor: TJSONObject;
    json_valor: variant;
    lista_de_url, lista_de_resultado_json: TStringList;
    sql_query:  TZQuery;
begin
    // Pra obter o ??ltimo concurso, deve-se enviar pra o webservice,
    // um concurso vazio e um timestamp da hora atual da solicita????o.
    url_lotofacil := lotofacil_url_download;
    url_lotofacil := ReplaceText(url_lotofacil, '@timestamp@', IntToStr(DateTimeToUnix(Now)));
    url_lotofacil := ReplaceText(url_lotofacil, '@concurso@', '');

    // Agora, vamos enviar a requisi????o
    obj_http := TIdHTTP.Create;
    obj_http.AllowCookies := True;
    obj_http.HandleRedirects := True;
    ;
    try
        conteudo_recebido := obj_http.Get(url_lotofacil, IndyTextEncoding_UTF8);
        conteudo_recebido := LowerCase(conteudo_recebido);

    except
        On exc: EIdHTTPProtocolException do
        begin
            MessageDlg('', 'Erro: ' + exc.Message, mtError, [mbOK], 0);
            Exit;
        end;
    end;

    // A requisi????o retorna um json, este json ?? um objeto
    resultado_json := GetJSON(conteudo_recebido);
    json_chave_valor := TJSONObject(resultado_json);

    if not Assigned(json_chave_valor) then
    begin
        MessageDlg('', 'Erro: Nenhum concurso localizado', mtError, [mbOK], 0);
        Exit;
    end;

    // Vamos obter o n??mero do concurso.
    json_valor := json_chave_valor.Get('nu_concurso');
    if varType(json_valor) = varnull then
    begin
        MessageDlg('', 'Erro: Nenhum concurso localizado', mtError, [mbOK], 0);
        Exit;
    end;

    // Aqui, obtemos o n??mero do concurso.
    ultimo_concurso := json_valor;

    // Os concursos s??o sorteados sequencialmente, ent??o, iremos gerar, a url
    // pra cada concurso, indo do ??ltimo ao primeiro concurso.
    lista_de_url := TStringList.Create;
    lista_de_url.Clear;
    for uA := ultimo_concurso downto 1 do
    begin
        url_lotofacil := lotofacil_url_download;
        url_lotofacil := ReplaceText(url_lotofacil, '@timestamp@', IntToStr(DateTimeToUnix(Now)));
        url_lotofacil := ReplaceText(url_lotofacil, '@concurso@', IntToStr(uA));
        lista_de_url.Add(url_lotofacil);
    end;

    // Agora, iremos fazer requisi????o pra o webservice pra obter o json de cada
    // url.
    lista_de_resultado_json := TStringList.Create;
    lista_de_resultado_json.Clear;
    for uA := 0 to Pred(lista_de_url.Count) do
    begin
        try
            url_lotofacil := lista_de_url.Strings[uA];
            conteudo_recebido := obj_http.Get(url_lotofacil, IndyTextEncoding_UTF8);
            conteudo_recebido := LowerCase(conteudo_recebido);
            lista_de_resultado_json.Add(conteudo_recebido);
        except
            On exc: Exception do
            begin
                // Isto, indica um erro no servidor, neste caso, devemos descartar esta requisi????o.
                // e continuar o processamento, este erro vai ocorrer no concurso de n??mero 1.
                // Depois, irei criar um sql separadamente pra o concurso de n??mero 1.
                if (obj_http.ResponseCode >= 500) and (obj_http.ResponseCode <= 599) then
                begin
                    continue;
                end;
            end;
        end;
    end;

    // Agora, irei gerar o sql de cada url, pra isto, irei analisar
    // cada json que foi obtido.
    sql_gerado := gerar_sql_dinamicamente(lista_de_resultado_json);

    // Agora, vamos inserir na tabela 'd_sorte.d_sorte_resultado_importacao'.
    try
        sql_query := TZQuery.Create(nil);
        sql_query.Connection := sql_conexao;
        sql_query.Connection.AutoCommit := False;

        sql_query.Sql.Clear;
        sql_query.SQL.Add('Truncate lotofacil.lotofacil_resultado_importacao;');
        sql_query.Sql.Add(sql_gerado);
        sql_query.ExecSQL;
        sql_query.Connection.Commit;
        sql_query.Close;
    except
        ON Exc: Exception do
        begin
            sql_query.Connection.Rollback;
            sql_query.Close;

            MessageDlg('', 'Erro: ' + exc.Message, mtError, [mbOK], 0);
            Exit;
        end;
    end;

    // Se chegarmos aqui, quer dizer, que os concursos foram importados.
    exibir_concursos_importados(sql_conexao, sgr_controle);

end;

{
 Exibe em um controle TStringGrid, os concursos importados.
}
procedure exibir_concursos_importados(sql_conexao: TZConnection; sgr_controle: TStringGrid);
const
    sql_nome_dos_campos: array [0..37] of string = (
        'status',
        'status_ja_inserido',
        'concurso',
        'data',
        'data_proximo_concurso',
        'b_1',
        'b_2',
        'b_3',
        'b_4',
        'b_5',
        'b_6',
        'b_7',
        'b_8',
        'b_9',
        'b_10',
        'b_11',
        'b_12',
        'b_13',
        'b_14',
        'b_15',

        'qt_ganhadores_15_numeros',
        'qt_ganhadores_14_numeros',
        'qt_ganhadores_13_numeros',
        'qt_ganhadores_12_numeros',
        'qt_ganhadores_11_numeros',

        'rateio_15_numeros',
        'rateio_14_numeros',
        'rateio_13_numeros',
        'rateio_12_numeros',
        'rateio_11_numeros',

        'acumulado_15_numeros',
        'acumulado_14_numeros',

        'valor_arrecadado',
        'valor_acumulado_especial',
        'estimativa_premio',

        'concurso_especial',
        'sorteio_acumulado',
        'rateio_processamento');

    sgr_controle_cabecalho: array [0..37] of string = (
        'STATUS',
        'STATUS_JA_INSERIDO',
        'CONCURSO',
        'DATA',
        'DATA_PROX_CONC',
        'b_1',
        'b_2',
        'b_3',
        'b_4',
        'b_5',
        'b_6',
        'b_7',
        'b_8',
        'b_9',
        'b_10',
        'b_11',
        'b_12',
        'b_13',
        'b_14',
        'b_15',

        'QT_G_15_NUM',
        'QT_G_14_NUM',
        'QT_G_13_NUM',
        'QT_G_12_NUM',
        'QT_G_11_ACERTOS',

        'RATEIO_15_NUM',
        'RATEIO_14_NUM',
        'RATEIO_13_NUM',
        'RATEIO_12_NUM',
        'RATEIO_11_NUM',

        'ACUM_15_NUM',
        'ACUM_14_NUM',

        'VLR_ARRECADADO',
        'VLR_ACUM_ESPECIAL',
        'ESTIMATIVA_PREMIO',

        'CONCURSO_ESPECIAL',
        'SORTEIO_ACUMULADO',
        'RATEIO_PROCESSAMENTO');
var
    sql_query: TZQuery;
    coluna_atual_controle: TGridColumn;
    formato_brasileiro: TFormatSettings;
    valor_campo_atual, nome_do_campo: string;
    uA: integer;
    linha_atual, coluna_atual: integer;
    qt_registros: longint;
    numero_decimal: extended;
    data_concurso: TDateTime;
begin
    try
        sql_query := TZQuery.Create(nil);
        sql_query.Connection := sql_conexao;
        sql_query.Connection.AutoCommit := True;

        sql_query.Sql.Clear;
        sql_query.Sql.Add('Select * from lotofacil.v_lotofacil_resultado_importacao');
        sql_query.Sql.Add('order by concurso desc');
        sql_query.Open;

        sql_query.First;
        sql_query.Last;
        qt_registros := sql_query.RecordCount;

        if qt_registros <= 0 then
        begin
            sgr_controle.Columns.Clear;
            coluna_atual_controle := sgr_controle.Columns.Add;
            coluna_atual_controle.Alignment := taCenter;
            sgr_controle.RowCount := 1;
            sgr_controle.Cells[0, 0] := 'Nenhum registro localizado.';
            sgr_controle.AutoSizeColumns;
            Exit;
        end;

        // Vamos configurar o controle.
        sgr_controle.Columns.Clear;
        for uA := 0 to High(sgr_controle_cabecalho) do
        begin
            coluna_atual_controle := sgr_controle.Columns.Add;
            coluna_atual_controle.Alignment := taCenter;
            coluna_atual_controle.Title.Caption := sgr_controle_cabecalho[uA];
            coluna_atual_controle.Title.Alignment := taCenter;
        end;
        sgr_controle.FixedRows := 1;
        sgr_controle.FixedCols := 0;

        // Vamos inserir os registros;
        // Haver?? uma linha a mais por causa do cabe??alho.
        sgr_controle.RowCount := qt_registros + 1;
        sgr_controle.FixedCols := 0;

        // Os n??meros decimais est??o em formato americano, iremos
        // representar visualmente em formato brasileiro.
        formato_brasileiro.DecimalSeparator := ',';
        formato_brasileiro.DateSeparator := '-';
        formato_brasileiro.ThousandSeparator := '.';
        formato_brasileiro.LongDateFormat := 'dd-mm-yyyy';
        formato_brasileiro.ShortDateFormat := 'dd-mm-yyyy';

        sql_query.First;
        for linha_atual := 1 to qt_registros do
        begin
            for coluna_atual := 0 to High(sql_nome_dos_campos) do
            begin
                // Vamos pegar o nome do campo e o valor do campo
                nome_do_campo := sql_nome_dos_campos[coluna_atual];
                nome_do_campo := LowerCase(nome_do_campo);

                valor_campo_atual := sql_query.FieldByName(sql_nome_dos_campos[coluna_atual]).AsString;
                valor_campo_atual := LowerCase(valor_campo_atual);
                valor_campo_atual := Trim(valor_campo_atual);

                // H?? tr??s situa????es interessantes, h?? na tabela, campos do tipo boolean que retorna
                // um true, ou false, e h?? tamb??m campos do tipo num??rico que tem dados nulos, neste
                // caso valor_campo_atual vai armazenar um string nulo, neste caso, ao passar
                // nas fun????es que convertem pra float pode ter problema, pra isto iremos manipular
                // esta situa????o.
                if (valor_campo_atual = '') or (valor_campo_atual = 'true') or
                    (valor_campo_atual = 'false') then
                begin
                    sgr_controle.Cells[coluna_atual, linha_atual] := valor_campo_atual;
                    Continue;
                end;



                //Writeln('campo: ', nome_do_campo, ', valor: ', valor_campo_atual);


                // No banco de dados, os campos que tem o tipo decimal, o separador
                // de decimal ?? o ponto e n??o a v??rgula, ent??o, iremos manipular esta situa????o
                if (nome_do_campo = 'rateio_15_numeros') or (nome_do_campo = 'rateio_14_numeros') or
                    (nome_do_campo = 'rateio_13_numeros') or (nome_do_campo = 'rateio_12_numeros') or
                    (nome_do_campo = 'rateio_11_numeros') or (nome_do_campo = 'valor_arrecadado') or
                    (nome_do_campo = 'valor_acumulado_especial') or
                    (nome_do_campo = 'estimativa_premio') then

                begin
                    numero_decimal := StrToFloat(valor_campo_atual);
                    sgr_controle.Cells[coluna_atual, linha_atual] := FloatToStr(numero_decimal, formato_brasileiro);
                end
                else if (nome_do_campo = 'data') or (nome_do_campo = 'data_proximo_concurso') then
                begin
                    data_concurso := StrToDate(valor_campo_atual, '-');
                    sgr_controle.Cells[coluna_atual, linha_atual] :=
                        DateToStr(data_concurso, formato_brasileiro);
                    valor_campo_atual := DateToStr(data_concurso, formato_brasileiro);
                end
                else
                begin
                    sgr_controle.Cells[coluna_atual, linha_atual] := valor_campo_atual;
                end;
            end;
            sql_query.Next;
        end;
        sgr_controle.AutoAdjustColumns;
    except
        On Exc: Exception do
        begin
            sgr_controle.Columns.Clear;
            coluna_atual_controle := sgr_controle.Columns.Add;
            coluna_atual_controle.Alignment := taCenter;
            sgr_controle.RowCount := 1;
            sgr_controle.Cells[0, 0] := Exc.Message;
            sgr_controle.AutoSizeColumns;
            FreeAndNil(sql_query);
            Exit;
        end;
    end;

    FreeAndNil(sql_query);

end;

{
 Aqui, iremos gerar o sql do json que foi retornado.
}
function gerar_sql_dinamicamente(lista_de_resultado_json: TStringList): string;
var
    json_data: TJsonData;

    // H?? 25 bolas, o ??ndice corresponde ao n??mero da bola,
    // o ??ndice 0 n??o ?? utilizado.
    lotofacil_bolas: array[0..25] of integer;

    // Concurso retorna somente 15 bolas.
    lotofacil_concurso_bolas: array[0..15] of integer;

    lista_de_sql:    TStringList;
    uA, uB, indice_bolas: integer;
    json_value:      variant;
    data_do_concurso: TDateTime;
    outra_data:      TDateTime;
    data_concurso:   array of string;
    data_convertida: array of string;
    bolas_ordenadas: TStringArray;
    bola_numero:     longint;
    sql_insert:      string;
    formato_numero_decimal: TFormatSettings;
    arquivo_sql:     Text;
begin
    // O sql ser?? formado desta maneira.
    // Insert campo_1, campo_2 values (valor_1, valor_2), (valor_1, valor_2);
    lista_de_sql := TStringList.Create;
    lista_de_sql.Clear;

    for uA := 0 to Pred(lista_de_resultado_json.Count) do
    begin
        Writeln(lista_de_resultado_json.Strings[ua]);
        json_data := GetJSON(lista_de_resultado_json.Strings[ua]);


        // ============ N??MERO DO CONCURSO. ==================
        json_value := TJsonObject(json_data).Get('nu_concurso');
        if vartype(json_value) = varnull then
        begin
            continue;
        end;
        if uA <> 0 then
        begin
            lista_de_sql.Add(',');
        end;
        lista_de_sql.Add('(');
        lista_de_sql.Add(json_value);
        if json_value = 428 then
            Writeln('Erro.');

        if json_value = 3 then
        begin
            writeln('');
        end;

        // ============ DATA ======================
        // Aqui, a data est?? em formato brasileiro, interseparados
        // pelo caractere '/'.
        json_value := TJsonObject(json_data).Get('dt_apuracaostr');
        data_concurso := string(json_value).Split('/');
        if Length(data_concurso) <> 3 then
        begin
            MessageDlg('', 'Erro, data: ' + json_value + ' incorreto.',
                mtError, [mbOK], 0);
            Exit;
        end;
        // O arranjo est?? desta forma:
        // dia-mes-ano.
        // data_concurso[0] := dia
        // data_concurso[1] := mes
        // data_concurso[2] := ano
        SetLength(data_convertida, 3);
        // Iremos organizar a data neste formato:
        // ano-mes-dia.
        data_convertida[0] := data_concurso[2];
        data_convertida[1] := data_concurso[1];
        data_convertida[2] := data_concurso[0];
        lista_de_sql.Add(',' + QuotedStr(data_convertida[0] + '-' + data_convertida[1] +
            '-' + data_convertida[2]));

        // ============ DATA PR??XIMO CONCURSO ======================
        // Aqui, a data est?? em formato brasileiro, interseparados
        // pelo caractere '/'.
        json_value := TJsonObject(json_data).Get('dtproximoconcursostr');
        if vartype(json_value) = varnull then
        begin
            lista_de_sql.Add(', null');
        end
        else
        begin
            data_concurso := string(json_value).Split('/');
            if Length(data_concurso) <> 3 then
            begin
                MessageDlg('', 'Erro, data: ' + json_value + ' incorreto.',
                    mtError, [mbOK], 0);
                Exit;
            end;
            // A data est?? neste formato:
            // dia-mes-ano.
            // data_concurso[0] := dia
            // data_concurso[1] := mes
            // data_concurso[2] := ano
            SetLength(data_convertida, 3);
            // Irei organizar a data neste formato:
            // ano-mes-dia.
            data_convertida[0] := data_concurso[2];
            data_convertida[1] := data_concurso[1];
            data_convertida[2] := data_concurso[0];
            lista_de_sql.Add(',' + QuotedStr(data_convertida[0] + '-' + data_convertida[1] +
                '-' + data_convertida[2]));
        end;

        // ================= BOLAS SORTEADAS =======================
        // No json, o campo resultadoordenado, armazena as bolas interseparadas
        // pelo caractere '-'
        json_value := TJsonObject(json_data).Get('resultadoordenado');
        bolas_ordenadas := string(json_value).Split('-');
        if Length(bolas_ordenadas) <> 15 then
        begin
            MessageDlg('', 'Erro, nao h?? 15 bolas no concurso.', mtError, [mbOK], 0);
            Exit;
        end;
        // N??o iremos confiar no webservice, sempre devemos verificar por bolas
        // duplicadas e foram de ordem.
        // As bolas correspondem os ??ndices do vetor, por isso, devemos
        FillChar(lotofacil_bolas, 26 * sizeof(integer), 0);
        for uB := 0 to Pred(Length(bolas_ordenadas)) do
        begin
            try
                // Verificar se o n??mero da bola ?? v??lida pra aquele jogo.
                bola_numero := StrToInt(bolas_ordenadas[uB]);
                if (bola_numero < 1) or (bola_numero > 25) then
                begin
                    MessageDlg('', 'Erro, bola inv??lida: ' + IntToStr(bola_numero),
                        mtError, [mbOK], 0);
                    Exit;
                end;
            except
                On Exc: Exception do
                begin
                    MessageDlg('', 'Erro: ' + Exc.Message, mtError, [mbOK], 0);
                    Exit;
                end;
            end;
            // Verifica bolas duplicadas.
            if lotofacil_bolas[bola_numero] = 1 then
            begin
                MessageDlg('', 'Erro, bola j?? foi sorteada', mtError, [mbOK], 0);
                Exit;
            end;
            lotofacil_bolas[bola_numero] := 1;
        end;

        // Pega as bolas ordenadas.
        indice_bolas := 0;
        for uB := 1 to 25 do
        begin
            if lotofacil_bolas[uB] = 1 then
            begin
                lotofacil_concurso_bolas[indice_bolas] := uB;
                Inc(indice_bolas);
                if indice_bolas = 15 then
                begin
                    break;
                end;
            end;
        end;

        // Gera o sql dinamicamente.
        // As bolas est?? armazenada de 0 a 14.
        for uB := 0 to Pred(Length(bolas_ordenadas)) do
        begin
            lista_de_sql.Add(', ' + IntToStr(lotofacil_concurso_bolas[uB]));
        end;

        // ============================================================
        // Aqui, iremos pegar os valores dos campos:
        // qt_ganhador_faixa_1, que corresponde a quantidade de ganhadores de 15 n??meros.
        // qt_ganhador_faixa_2, que corresponde a quantidade de ganhadores de 14 n??meros.
        // qt_ganhador_faixa_3, que corresponde a quantidade de ganhadores de 13 n??meros.
        // qt_ganhador_faixa_4, que corresponde a quantidade de ganhadores de 12 n??meros.
        // qt_ganhador_faixa_5, que corresponde a quantidade de ganhadores de 11 n??meros.
        // Tais n??meros s??o n??meros inteiros e n??o decimais, nenhuma convers??o necess??ria.
        for uB := 1 to 5 do
        begin
            json_value := TJsonObject(json_data).Get('qt_ganhador_faixa' + IntToStr(uB));
            lista_de_sql.Add(',' + IntToStr(json_value));
            Writeln(FloatToStr(json_value));
        end;

        // ============================================================
        // Aqui, iremos pegar os valores dos campos:
        // qt_rateio_faixa_1, que corresponde ao valor que cada ganhador de 15 acertos recebeu.
        // qt_rateio_faixa_2, que corresponde ao valor que cada ganhador de 14 acertos recebeu.
        // qt_rateio_faixa_3, que corresponde ao valor que cada ganhador de 13 acertos recebeu.
        // qt_rateio_faixa_4, que corresponde ao valor que cada ganhador de 12 acertos recebeu.
        // qt_rateio_faixa_5, que corresponde ao valor que cada ganhador de 11 acertos recebeu.
        // Aqui, o n??mero est?? no formato americano.
        formato_numero_decimal.DecimalSeparator := '.';
        formato_numero_decimal.ThousandSeparator := ',';
        for uB := 1 to 5 do
        begin
            json_value := TJsonObject(json_data).Get('vr_rateio_faixa' + IntToStr(uB));
            lista_de_sql.Add(',' + FloatToStr(double(json_value), formato_numero_decimal));
            Writeln(FloatToStr(double(json_value), formato_numero_decimal));
        end;

        // ================ VALOR ACUMULADO FAIXA 1 ====================
        // No json, 'vracumuladofaixa1' est?? em formato num??rico brasileiro.
        // Ele pode ser nulo, devemos evitar isto.
        json_value := TJsonObject(json_data).Get('vracumuladofaixa1');
        if vartype(json_value) = varnull then
        begin
            lista_de_sql.Add(', null');
        end
        else
        begin
            formato_numero_decimal.DecimalSeparator := ',';

            // Se fossemos converter um string num??rico em formato brasileiro, sem especificar,
            // o formato do n??mero, StrToFloat, espera que o n??mero esteja em formato americano,
            // por isso, devemos explicitar que o string tem um formato num??rico do brasil.
            json_value := ReplaceText(json_value, '.', '');
            json_value := StrToFloat(json_value, formato_numero_decimal);

            // Observe agora, que json_value, est?? em formato americano, pois float, s??o n??meros
            // decimais com ponto, sempre ser?? desta forma, se quisermos converter pra o formato
            // brasileiro, era simplesmente informar com isto, neste caso, n??o precisamos mais
            // mais pra garantir iremos explicitar que quando converter de float pra string,
            // o formato seja americano pois, sql espera receber um n??mero em formato americano.
            formato_numero_decimal.DecimalSeparator := '.';
            formato_numero_decimal.ThousandSeparator := ',';
            lista_de_sql.Add(',' + FloatToStr(double(json_value), formato_numero_decimal));
            Writeln(FloatToStr(double(json_value), formato_numero_decimal));
        end;

        // ================ VALOR ACUMULADO FAIXA 2 ====================
        // No json, 'vracumuladofaixa2' est?? em formato num??rico brasileiro.
        json_value := TJsonObject(json_data).Get('vracumuladofaixa2');
        if vartype(json_value) = varnull then
        begin
            lista_de_sql.Add(', null');
        end
        else
        begin
            formato_numero_decimal.DecimalSeparator := ',';

            // Se fossemos converter um string num??rico em formato brasileiro, sem especificar,
            // o formato do n??mero, StrToFloat, espera que o n??mero esteja em formato americano,
            // por isso, devemos explicitar que o string tem um formato num??rico do brasil.
            json_value := ReplaceText(json_value, '.', '');
            json_value := StrToFloat(json_value, formato_numero_decimal);

            // Observe agora, que json_value, est?? em formato americano, pois float, s??o n??meros
            // decimais com ponto, sempre ser?? desta forma, se quisermos converter pra o formato
            // brasileiro, era simplesmente informar com isto, neste caso, n??o precisamos mais
            // mais pra garantir iremos explicitar que quando converter de float pra string,
            // o formato seja americano pois, sql espera receber um n??mero em formato americano.
            formato_numero_decimal.DecimalSeparator := '.';
            lista_de_sql.Add(',' + FloatToStr(double(json_value), formato_numero_decimal));
            Writeln(FloatToStr(double(json_value), formato_numero_decimal));

            // ======================= Valor arrecadado =====================
            // O campo 'vrarrecadado' est?? em formato num??rico brasileiro.
            json_value := TJsonObject(json_data).Get('vrarrecadado');
            if vartype(json_value) = varnull then
            begin
                lista_de_sql.Add(', null');
            end
            else
            begin
                formato_numero_decimal.DecimalSeparator := ',';
                // Retirar o separador de milhar, pois o n??mero est?? em formato brasileiro.
                // e a fun????o StrToCurr n??o aceita o separador de milhar ao realizar a convers??o.
                json_value := ReplaceText(json_value, '.', '');
                json_value := StrToFloat(json_value, formato_numero_decimal);
                // Agora converter em formato num??rico americano.
                formato_numero_decimal.DecimalSeparator := '.';
                lista_de_sql.Add(',' + FloatToStr(double(json_value), formato_numero_decimal));
                Writeln(FloatToStr(double(json_value), formato_numero_decimal));
            end;
        end;

        // ======================= Valor acumulado especial ================
        // O campo 'vracumuladoespecial' est?? em formato num??rico brasileiro
        formato_numero_decimal.DecimalSeparator := ',';
        // Retirar o separador de milhar, pois o n??mero est?? em formato brasileiro.
        // e a fun????o StrToFloat n??o aceita o separador de milhar ao realizar a convers??o.
        json_value := TJsonObject(json_data).Get('vracumuladoespecial');
        if vartype(json_value) = varnull then
        begin
            lista_de_sql.Add(', null');
        end
        else
        begin
            formato_numero_decimal.DecimalSeparator := ',';
            json_value := ReplaceText(json_value, '.', '');
            json_value := StrToFloat(json_value, formato_numero_decimal);
            // Agora converter em formato americano.
            formato_numero_decimal.DecimalSeparator := '.';
            lista_de_sql.Add(',' + FloatToStr(double(json_value), formato_numero_decimal));
            Writeln(FloatToStr(double(json_value), formato_numero_decimal));
        end;

        // ===================== ESTIMATIVA ===========================
        // O campo 'vrestimativa' est?? em formato num??rico brasileiro.
        json_value := TJsonObject(json_data).Get('vrestimativa');
        if vartype(json_value) = varnull then
        begin
            lista_de_sql.Add(', null');
        end
        else
        begin
            formato_numero_decimal.DecimalSeparator := ',';
            json_value := ReplaceText(json_value, '.', '');
            json_value := StrToFloat(json_value, formato_numero_decimal);
            // Agora, converter em formato americano.
            formato_numero_decimal.DecimalSeparator := '.';
            lista_de_sql.Add(',' + FloatToStr(double(json_value), formato_numero_decimal));
            Writeln(FloatToStr(double(json_value), formato_numero_decimal));
        end;

        // ======================= ?? um concurso especial ======================
        json_value := TJsonObject(json_data).Get('ic_concurso_especial');
        if json_value = True then
        begin
            lista_de_sql.add(',true');
        end
        else if json_value = False then
        begin
            lista_de_sql.Add(',false');
        end
        else
        begin
            lista_de_sql.Add(',null');
        end;

        // =================== sorteio acumulado =====================
        json_value := TJsonObject(json_data).Get('sorteio_acumulado');
        if json_value = True then
        begin
            lista_de_sql.add(',true');
        end
        else if json_value = False then
        begin
            lista_de_sql.Add(',false');
        end
        else
        begin
            lista_de_sql.Add(',null');
        end;

        // =================== Rateio processamento ==================
        json_value := TJsonObject(json_data).Get('rateioprocessamento');
        if json_value = True then
        begin
            lista_de_sql.add(',true');
        end
        else if json_value = False then
        begin
            lista_de_sql.Add(',false');
        end
        else
        begin
            lista_de_sql.Add(',null');
        end;

        // Fecha o insert do registro atual
        lista_de_sql.Add(')');

    end;

    // Gera o cabe????lho do insert, observe que a ordem dos campos
    // tem que ser igual ao insert dos valores, no loop for acima,
    // se o usu??rio alterar o valor dos insert de posi????o, deve-se
    // alterar este cabe??alho.
    sql_insert := 'Insert into lotofacil.lotofacil_resultado_importacao(';
    sql_insert := sql_insert + 'concurso, data, data_proximo_concurso,';
    sql_insert := sql_insert + 'b_1, b_2, b_3, b_4, b_5, b_6, b_7, b_8, b_9, b_10, b_11, b_12, b_13, b_14, b_15';
    sql_insert := sql_insert + ',qt_ganhadores_15_numeros';
    sql_insert := sql_insert + ',qt_ganhadores_14_numeros';
    sql_insert := sql_insert + ',qt_ganhadores_13_numeros';
    sql_insert := sql_insert + ',qt_ganhadores_12_numeros';
    sql_insert := sql_insert + ',qt_ganhadores_11_numeros';
    //sql_insert := sql_insert + ',qt_ganhadores_mes_de_sorte';
    sql_insert := sql_insert + ',rateio_15_numeros';
    sql_insert := sql_insert + ',rateio_14_numeros';
    sql_insert := sql_insert + ',rateio_13_numeros';
    sql_insert := sql_insert + ',rateio_12_numeros';
    sql_insert := sql_insert + ',rateio_11_numeros';

    sql_insert := sql_insert + ', acumulado_15_numeros';
    sql_insert := sql_insert + ', acumulado_14_numeros';

    sql_insert := sql_insert + ', valor_arrecadado';
    sql_insert := sql_insert + ', valor_acumulado_especial';
    sql_insert := sql_insert + ', estimativa_premio';

    sql_insert := sql_insert + ', concurso_especial';
    sql_insert := sql_insert + ', sorteio_acumulado';
    sql_insert := sql_insert + ', rateio_processamento';

    sql_insert := sql_insert + ') values';

    lista_de_sql.Insert(0, sql_insert);
    Exit(lista_de_sql.Text);
end;

end.
