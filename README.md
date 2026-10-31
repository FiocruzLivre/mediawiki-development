# Imagem MediaWiki compartilhada

Imagem e Docker Compose utilizados no desenvolvimento, na homologação e na produção do [MapaMovSaúde](https://github.com/FiocruzLivre/mapa-mov-saude) e da [WikiFavelas](https://github.com/FiocruzLivre/wikifavelas-mediawiki). Configurações, extensões e dados de cada wiki ficam em seus próprios repositórios e servidores.

## Uso local

```sh
docker compose up -d --build
```

Instalação nova: abra http://localhost:8080 para configurar o MediaWiki; mensagens de teste em http://localhost:8025. O código fica em `volumes/mediawiki`, enquanto a configuração da wiki pode ser montada em `volumes/src/mediawiki`. Os valores locais estão no [Compose](docker-compose.yml); coloque alterações e segredos apenas no `.env` não versionado.

## Instalação atrás de proxy ou com banco externo

Copie `docker-compose.override.example.yml` para `docker-compose.override.yml` (ignorado pelo Git) e configure no `.env` as variáveis exigidas. O exemplo **não** publica portas, não inicia MariaDB ou Mailpit e desativa Xdebug. Conecte o serviço MediaWiki à rede do proxy e do banco externo conforme a instalação. Confira o resultado de `docker compose config` e de `docker compose config --services` antes de subir os contêineres. Não copie os valores de senha de desenvolvimento para produção.

## Atualizações

O [Renovate](renovate.json) propõe PRs de versões após sua habilitação no GitHub, sem merge ou deploy automático. Como o MediaWiki 1.46.2 fixa o Symfony YAML em uma versão vulnerável, o build permite atualizações compatíveis na série 7.4 e executa `composer audit`. Essa exceção temporária deve ser retirada quando uma versão estável do MediaWiki incorporar a correção.

Para publicar no registry da organização, depois de revisar e integrar o PR, crie uma tag no branch `main` como `1.46.2-r1`. O workflow publica `ghcr.io/fiocruzlivre/mediawiki:1.46.2-r1` e uma tag imutável com o SHA, somente após os testes. A revisão `r2` representa outra compilação da **mesma versão MediaWiki**. Não é criado `latest` e não há implantação automática.

**Atenção:** a imagem só copia o código MediaWiki para `volumes/mediawiki` quando o volume está vazio. Atualizar a imagem **não atualiza** o código ou dependências de um volume já existente. Em produção, revise as diferenças e as versões de extensões, valide backup/restauração, atualize uma cópia isolada, execute `php maintenance/run.php update` quando necessário e só então promova o release validado. Planeje reversão de banco, arquivos e código juntos.
