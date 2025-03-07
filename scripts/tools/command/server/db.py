from peewee import BooleanField, CharField, Model, SqliteDatabase
from playhouse.sqlite_ext import JSONField

db = SqliteDatabase('task.db', pragmas={'foreign_keys': 1})
db.connect()

class Task(Model):
    task_type = CharField()
    config = JSONField()
    status = CharField(default="Pending")
    result = JSONField(default={})

    class Meta:
        database = db
        
Task.create_table(safe=True)