# Atualização de uma instalação MediaWiki

Trocar a tag da imagem Docker **não** atualiza automaticamente o código MediaWiki em um volume persistente.

1. **Inventarie** as versões do MediaWiki, PHP, banco, extensões e skins, além dos volumes, configurações e customizações.
2. **Valide os backups existentes:** banco, uploads e configurações. Verifique uma restauração em ambiente isolado; não crie destinos improvisados.
3. **Separe a homologação:** banco, volumes, portas e nome de projeto próprios, sem acesso de escrita aos dados de produção.
4. **Atualize em homologação:** selecione a versão de código compatível, ajuste extensões e dependências fixadas, revise avisos de segurança e execute:

   ```sh
   docker compose build mediawiki
   docker compose up -d
   docker compose exec mediawiki php maintenance/run.php update
   ```

5. **Teste os fluxos reais:** login, permissões, edição visual e de código, upload e miniaturas, formulários, mapas, busca, tarefas e e-mails, quando instalados. Confira logs e desempenho; HTTP 200 isoladamente não comprova compatibilidade.
6. **Publique com autorização:** janela de manutenção, bloqueio controlado de escritas, backup final no mecanismo habitual, release reproduzível e testes funcionais após a atualização.

Uma atualização do esquema do banco pode exigir **restaurar o banco, código e configuração da versão anterior** para reverter. Trocar apenas a imagem do contêiner não é uma estratégia de reversão suficiente.
