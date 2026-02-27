extends Node
## Carrega traduções do CSV manualmente e registra no TranslationServer.
## Autoload — roda antes de qualquer cena.


func _ready() -> void:
	_load_csv_translations("res://localization/localization.csv")


func _load_csv_translations(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("Localization CSV not found: %s" % path)
		return

	# Ler cabeçalho: keys, en, pt, ...
	var header_line := file.get_csv_line()
	if header_line.size() < 2:
		push_warning("Localization CSV has no language columns")
		return

	# Criar um Translation por idioma
	var translations: Array[Translation] = []
	for i in range(1, header_line.size()):
		var t := Translation.new()
		t.locale = header_line[i].strip_edges()
		translations.append(t)

	# Ler cada linha e registrar as mensagens
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 2 or row[0].strip_edges() == "":
			continue
		var key := row[0].strip_edges()
		for i in range(1, mini(row.size(), header_line.size())):
			translations[i - 1].add_message(key, row[i].strip_edges())

	# Registrar no TranslationServer
	for t in translations:
		TranslationServer.add_translation(t)
