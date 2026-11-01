# Testes

- **`scripts/`**: contratos dos scripts de preparação e validação de tags, com diretórios temporários e sem contêineres.
- **`configuration/`**: configuração efetiva do Docker Compose, sem iniciar serviços.
- **`integration/`**: imagem, Apache e banco reais, em ambiente Docker descartável.

A CI executa os dois primeiros grupos sem construir imagens. O grupo de integração só roda após `docker compose up -d --build` e inclui cenários de autenticação, indisponibilidade e recuperação do banco.

O teste de banco separado inicia outro contêiner MediaWiki usando o serviço MariaDB da rede de testes. Verifica autenticação e inicialização HTTP; **não** simula uma wiki já instalada nem substitui testes funcionais das instalações MapaMovSaúde e WikiFavelas.

Executar os testes rápidos: `bats tests/configuration/*.bats tests/scripts/*.bats`. Para integração, inicie um ambiente descartável com `docker compose up -d --build` e execute `bats tests/integration/*.bats`. Esses testes interrompem e reiniciam o banco de teste: nunca os execute contra serviços de produção.
