Bundle hors-ligne de motion-tools-and-skills (genere par scripts/publish-bundle.sh).
Archives > 90 Mo : fichiers NOM.tar.gz.part-000, -001... Reconstituer puis verifier :
  cat NOM.tar.gz.part-* > NOM.tar.gz && sha256sum -c SHA256SUMS
Puis : tar xzf NOM.tar.gz && cd motion-tools-bundle && bash scripts/run.sh setup && bash scripts/check.sh
