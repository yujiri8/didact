get "/spem/words" do |env|
  begin
    name = env.params.query["word"]?
    notes = env.params.query["notes"]?
    notes_regex = env.params.query["notes_regex"]?
    raw = !env.params.query["raw"]?.nil?
    translations = env.params.query.fetch_all("translation")
    tags = env.params.query.fetch_all("tag")
  rescue
    raise UserErr.new(400)
  end
  where = ["TRUE"] of String
  args = [] of String
  if name
    # Array parameters don't work, so convert the names to a tuple of placeholders.
    names = name.split(/ /, remove_empty: true)
    where << "name IN (#{(names.map { |_| "?" }).join(",")})"
    args.concat names
  end
  if notes
    where << "notes REGEXP ?"
    args << "\\b#{Regex.escape(notes)}\\b"
  end
  if notes_regex
    where << "notes REGEXP ?"
    args << notes_regex
  end
  translations.each do |t|
    where << "? IN (SELECT translation FROM translations WHERE word_id = words.id)"
    args << t
  end
  tags.each do |t|
    where << "? IN (SELECT tag FROM tags WHERE word_id = words.id)"
    args << t
  end
  get_words(env.db, "#{where.join(" AND ")} ORDER BY time_changed DESC", args: args).map(&.dict raw: raw).to_json
end

struct WordParams
  include JSON::Serializable
  property name : String
  property meaning : String
  property notes : String
  property translations : Array(String)
  property tags : Array(String)
end

post "/spem/words" do |env|
  Util.require_admin env
  begin
    params = WordParams.from_json env.request.body.not_nil!
  rescue e
    raise UserErr.new(400)
  end
  raise UserErr.new(400, detail = "There's already a word called that") \
     if env.db.scalar("SELECT EXISTS (SELECT id FROM words WHERE name = ?)", params.name) != 0
  word = Word.new(
    name: params.name,
    meaning: params.meaning,
    notes: params.notes,
    translations: params.translations,
    tags: params.tags,
    time_added: Time.utc,
    time_changed: Time.utc,
  )
  word.validate
  add_word env.db, word
end

put "/spem/words" do |env|
  Util.require_admin env
  begin
    params = WordParams.from_json env.request.body.not_nil!
  rescue e
    raise UserErr.new(400)
  end
  word = get_word(env.db, "name = ?", [params.name])
  word.meaning = params.meaning
  word.notes = params.notes
  word.translations = params.translations
  word.tags = params.tags
  word.time_changed = Time.utc
  word.validate
  change_word env.db, word
end

delete "/spem/words/:name" do |env|
  Util.require_admin env
  env.db.exec "DELETE FROM words WHERE name = ?", env.params.url["name"]
end

get "/spem/tags" do |env|
  env.db.query_all("SELECT DISTINCT tag FROM tags ORDER BY tag", as: String).to_json
end
