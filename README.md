# Imagem MediaWiki compartilhada

Imagem e Docker Compose utilizados no desenvolvimento, na homologação e na produção do [MapaMovSaúde](https://github.com/FiocruzLivre/mapa-mov-saude) e da [WikiFavelas](https://github.com/FiocruzLivre/wikifavelas-mediawiki). Configurações, extensões e dados de cada wiki ficam em seus próprios repositórios e servidores.

## Uso local

```sh
docker compose up -d --build
```

Instalação nova: abra http://localhost:8080 para configurar o MediaWiki; mensagens de teste em http://localhost:8025. O código fica em `volumes/mediawiki`, enquanto a configuração da wiki pode ser montada em `volumes/src/mediawiki`. Os valores locais estão no [Compose](docker-compose.yml); coloque alterações e segredos apenas no `.env` não versionado.

## Instalação atrás de proxy ou com banco externo

Consulte o [guia de implantação](docs/deployment.md) para criar o `docker-compose.override.yml` privado, configurar banco externo e proxy reverso e desativar serviços locais. Confira o Compose resultante antes de iniciar os contêineres. Nunca use credenciais de desenvolvimento em produção.

## Atualizações

O [Renovate](renovate.json) propõe PRs de versões após sua habilitação no GitHub, sem merge ou deploy automático. Como o MediaWiki 1.46.2 fixa o Symfony YAML em uma versão vulnerável, o build permite atualizações compatíveis na série 7.4 e executa `composer audit`. Essa exceção temporária deve ser retirada quando uma versão estável do MediaWiki incorporar a correção.

A cada merge na `main`, o workflow [Publicar imagem MediaWiki no GHCR](.github/workflows/publish-mediawiki-image.yml) constrói a imagem, executa os testes e publica **essa mesma imagem testada** em `ghcr.io/fiocruzlivre/mediawiki`. As tags seguem o formato `1.46.2-rN` (versão do MediaWiki + número sequencial da execução do workflow) e `sha-<commit>`; as revisões são únicas, não necessariamente consecutivas em caso de falha, e não reiniciam ao atualizar a versão do MediaWiki. Não é necessário criar tags Git manualmente. Não publicamos `latest` e **não há deploy automático**; cada instalação escolhe qual revisão promover.

**Atenção:** a imagem só copia o código MediaWiki para `volumes/mediawiki` quando o volume está vazio. Atualizar a imagem **não atualiza** o código ou dependências de um volume já existente. Em produção, revise as diferenças e as versões de extensões, valide backup/restauração, atualize uma cópia isolada, execute `php maintenance/run.php update` quando necessário e só então promova o release validado. Planeje reversão de banco, arquivos e código juntos.
