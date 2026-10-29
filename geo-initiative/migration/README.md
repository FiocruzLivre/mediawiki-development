# Migração dos 82 marcadores (revisão 2576)

Este diretório contém somente ferramentas de auditoria e geração de propostas. **Nenhuma ferramenta edita a wiki.** A implantação depende de aprovação editorial e da definição do contrato final de armazenamento.

## Executar

```sh
python3 geo-initiative/migration/audit.py
python3 geo-initiative/migration/migrate.py --dry-run
python3 geo-initiative/migration/compare.py --generated /caminho/geojson-gerado.json
python3 -m unittest discover -s geo-initiative/migration/tests
```

O relatório `inventory.csv` preserva propriedades originais, coordenadas, títulos e page IDs. `editorial-review.csv` lista registros com alertas; `quality.json` documenta o resumo e hash do wikitext.

## Garantias e limitações

- Fonte: API MediaWiki, `Predefinição:Mapa Brasil`, revisão 2576, identificada por hash SHA-256. O inventário interrompe se a revisão mudar.
- O original contém comentários de linha `//`; são removidos exclusivamente durante o parsing em memória.
- A proposta não requer credenciais de escrita, não executa `action=edit` e é segura para execução repetida.
- Nenhum dado de geocodificação automática é aceito.
- Registros ausentes, redirecionamentos, nomes duplicados e coordenadas compartilhadas são bloqueados.
- Referências geográficas em conteúdo preexistente são bloqueadas conservadoramente. Antes de um executor real, validar também dados GeoData do artigo via API/abstração oficial, e resolver falsos positivos.
- `proposals.json` armazena `baserevid`, `basetimestamp`, SHA-256 da revisão consultada e apenas o fragmento sugerido, **não edições completas**.
- A marcação `{{Geolocalização do artigo|latitude=...|longitude=...}}` é ilustrativa. NÃO aplicar até que formulário, predefinição e persistência oficial tenham contrato aprovado.
- `compare.py` usa título como chave primária compatível com legado e valida page ID quando disponível no conjunto novo; renomes devem ser tratados por mapeamento editorial antes da publicação.
- O papel da coordenada (`geo_role`) é desconhecido em 82/82 registros; não interpretá-lo como sede.

## Transição e reversão

1. Congelar snapshot, inventário e hash da revisão; obter revisão e página de destino, verificar existência e permissão.
2. Revisar editorialmente 36 alertas estruturais; verificar papel e localização de todos os 82 pontos. Preservar valores originalmente fornecidos pelos autores.
3. Aprovar contrato de dados e conferir se artigos não adquiriram coordenadas após o snapshot.
4. Em homologação, implementar executor específico com API oficial MediaWiki: login autorizado, CSRF token, `action=edit`, `baserevid`, `basetimestamp`, `assert=user`, tratamento de conflito, proteção e rate limiting, histórico e log de resultados. Não existe executor de escrita nesta entrega.
5. Executar lote pequeno, reconciliar cada edição e relatório, confirmar GeoData e resultado GeoJSON.
6. Manter `Predefinição:Mapa Brasil` intacta até aprovação de um conjunto novo; comparar inclusão, exclusão, coordenada, título e multiplicidade sem aceitar automaticamente divergências.
7. Fazer cutover apenas em implantação independente com backup da revisão original e rollback testado. Evitar simultaneamente mapas duplicados; alternar fonte/renderização de forma reversível.
8. Para reversão, restaurar fonte visual legada sem desfazer edições legítimas de autores. Se necessário desfazer dados migrados, somente com autorização, checagem de revisão e remoção do fragmento exato adicionado pelo migrador, mantendo o conteúdo posterior.

Critério de aprovação: zero perdas não justificadas, nenhuma substituição de coordenada inserida por autor, revisões conciliadas e validação editorial das divergências.

