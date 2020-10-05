require "./cfg"
Granite::Connections << Granite::Adapter::Pg.new(name: "db", url: "postgres://#{CFG.postgres.user}@localhost/#{CFG.postgres.db}")
require "granite/adapter/pg"

class Comment < Granite::Base
  connection db
  table comments
  column id : Int64, primary: true
  column name : String
  column body : String
  column article_path : String
  column article_title : String
  column ip : String?
  column ua : String?
  column time_added : Time
  column time_changed : Time?
  belongs_to parent : Comment, foreign_key: reply_to : Int64?
  has_many replies : Comment, foreign_key: :reply_to
  has_many subs : Subscription
  belongs_to :user
  alias CommentJson = Int64 | String | Bool | Time | Nil | Array(Hash(String, CommentJson))

  def dict(user = nil, raw = false, recursion = 5) : Hash(String, CommentJson)
    cmt = {
      "id"           => @id,
      "name"         => @name,
      "reply_to"     => @reply_to,
      "body"         => (raw ? @body : Util.markdown @body.as(String)),
      "time_added"   => @time_added,
      "time_changed" => @time_changed,
      "replies"      => recursion > 0 ? self.replies.map &.dict(user: user, raw: raw, recursion: recursion - 1) : self.replies.size.to_i64,
    } of String => CommentJson
    # If a user is provided, attach whether they're subscribed to the comment and whether it's theirs.
    if !user.nil?
      cmt["sub"] = self.subs.find_by(user_id: user.id).try &.sub || nil
      cmt["owned"] = user.id == self.user.id
    end
    cmt
  end

  def summary_dict
    {
      "id"            => @id,
      "name"          => @name,
      "article_title" => @article_title,
      "link"          => "#{@article_path}?c=#{@id}#comment-section",
      "time_added"    => @time_added,
    }
  end

  # Raises exception if the comment is invalid.
  def validate
    raise UserErr.new(400, "You need a name") if self.name == ""
    raise UserErr.new(400, "Your name can't be longer than 30 characters") if self.name.size > 30
    raise UserErr.new(400, "That name is taken by a registered user.") \
       if (name_owner = User.find_by(name: self.name)) && name_owner.id != self.user.id
    # One can be missing, but not both.
    raise UserErr.new(400) if @reply_to.nil? && @article_path.nil?
  end
end

class User < Granite::Base
  connection db
  table users
  column id : Int64, primary: true
  column email : String, unique: true
  column name : String?, unique: true
  column auth : String
  column pw : String?
  column disable_reset : Bool = false
  column admin : Bool = false
  column autosub : Bool = true
  column sub_site : Bool = false
  has_many :comment
  has_many comment_subs : Subscription
  has_many article_subs : ArticleSubscription
end

class Subscription < Granite::Base
  connection db
  table subs
  column id : Int64, primary: true
  belongs_to :comment
  belongs_to :user
  column sub : Bool = true

  def dict
    {
      "comment" => self.comment.summary_dict,
      "sub"     => @sub,
    }
  end
end

class ArticleSubscription < Granite::Base
  connection db
  table article_subs
  column id : Int64, primary: true
  column path : String
  column title : String
  belongs_to :user

  def dict
    {
      "path"  => @path,
      "title" => @title,
    }
  end
end

class Word < Granite::Base
  connection db
  table words
  column id : Int64, primary: true
  column name : String
  column meaning : String
  column translations : Array(String)
end
