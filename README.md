# Ambiente de desenvolvimento MediaWiki

Ambiente Docker Compose reutilizável para desenvolvimento e testes de projetos MediaWiki. As configurações de cada wiki ficam nos repositórios próprios, não aqui.

## Iniciar

```sh
git clone https://github.com/FiocruzLivre/mediawiki-development.git
cd mediawiki-development
docker compose up -d
```

Acesse o [MediaWiki](http://localhost:8080) e conclua a instalação inicial. Os e-mails de teste ficam no [Mailpit](http://localhost:8025).

O código do MediaWiki, os uploads e os dados ficam em `volumes/`. Para usar código existente, coloque-o em `volumes/mediawiki` **antes** de iniciar. Arquivos específicos do projeto podem ser montados em `volumes/src/mediawiki`.

Configure alterações de portas, credenciais locais e depuração por meio de um `.env` não versionado. As variáveis e os valores padrão estão em [docker-compose.yml](docker-compose.yml). **Os valores padrão não são adequados à produção.**

## Comandos úteis

```sh
docker compose logs -f mediawiki
docker compose down
```

Para ativar o Xdebug, defina `ENABLE_XDEBUG=1` e `XDEBUG_MODE=debug` no `.env` e reconstrua a imagem.

Antes de alterar versões ou executar a atualização do banco, siga [Atualização de instalações](docs/UPGRADING.md).
