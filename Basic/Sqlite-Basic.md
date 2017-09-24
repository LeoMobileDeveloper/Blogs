## SQLite

SQLite是一个关系型数据库，是一个嵌入式的数据库，它的核心代码由C编写，直接在宿主应用中运行。

本来想一篇长文章涵盖想写的内容，最后发现想写的东西太多了，就拆分成：基础篇，原理篇和iOS应用篇发出来吧。

MAC OS的命令行字带SQLite。以下示例均在命令行中进行，C API的使用会在之后的文章里讲解：

## 表

> 在关系型数据库中，[表](https://en.wikipedia.org/wiki/Table_(database))是一组相关数据的集合，它包括行和列。

命令行新建一个数据库：

```
sqlite3 person.sqlite3
```

然后，新建一个表，并且插入两条数据

```
create table person(id integer primary key,name text not null,phone text not null default 'unknown');
insert into person (id,name,phone) values(10001,'Leo','1234578901');
insert into person (id,name) values(10002,'Lina');
```

调整命令行显示模式：

```
.mode column
.headers on
```

然后，我们查询下当前数据库中的数据

```
select * from person;
```

结果

```
id          name        phone     
----------  ----------  ----------
10001       Leo         1234578901
10002       Lina        unknown 
```

删除表

```
drop table table_name
```

### 主键

> 主键指的是表中一个列或者多个列的组合，用来唯一的标识表中的的每一行。  
> 一个表中只能有一个primary key约束。

在创建数据库的时候，我们可以设置主键，通过`primary key`语法。例如，刚刚我们创建的数据库中，id是数据库的主键。

```
create table person(id integer primary key,name text not null,phone text not null default 'unknown');
```

这里，用户id是数据库的主键，因为它是唯一的。当你尝试插入一行，这行的主键在数据库中已存在的时候，会报错。

```
insert into person (id,name) values(10001,'Tom');
Error: UNIQUE constraint failed: person.id
```

> Tips: 如果主键是Integer，意味着主键可以自增。
比如：  

```
insert into person (name) values('Tom');实际插入了这样一行
id          name        phone     
----------  ----------  ----------
10003       Tom         unknown  
```



## Select

在查询之前，我们往数据库里再插入一些数据，方便我们做查询。此时数据库中的数据如下

```
id          name        phone     
----------  ----------  ----------
10001       Leo         1234578901
10002       Lina        unknown   
10003       Tom         unknown   
10004       Lily        unknown   
10005       Lucy        unknown   
10006       Jone        unknown   
10007       Kobe        unknown   
10008       Jeccy       unknown   
10009       Smith       1234567890
```

数据库查询语句，也就是select是SQL中最复杂的命令。select命令的通用形式如下：

```
select [distinct] heading 
from tables
where predicate
group by columns
having predicate
order by columns
limit count,offset;
```
这里的from,where等关键字都是一个单独的子句，每个子句由关键字和跟随参数组成。在理解select语句的时候，可以把整个过程当成一个管道处理
>即：上一个子句的输出作为下一个子句的输入

### where

where子句由 where + 断言组成。

比如：

```
sqlite> select name 
   ...> from person 
   ...> where phone!='unknown' and id>10005;
//结果
name      
----------
Smith  
```
> 这里的and是逻辑操作符，除了and，还有or，not和in。

断言也支持对字符串进行正则匹配：比如 where name like 'L%'。表示以L开头的字符串


### Order

order后跟着列名，用来排序。

比如: 查询id>10004的数据，结果按照name降序排列

```
sqlite> select *
   ...> from person
   ...> where id>10004
   ...> order by name DESC;
```
结果：

```
id          name        phone      
----------  ----------  -----------
10009       Smith       12345678902
10005       Lucy        unknown    
10007       Kobe        unknown    
10006       Jone        unknown    
10008       Jeccy       unknown 
```
### limit & offset

> limit和offset对结果集进行限定。

比如: 查询id>10004的数据，结果按照name降序排列，取第二个数据。

```
sqlite> select * 
   ...> from person 
   ...> where id>10004
   ...> order by Name DESC
   ...> limit 1 offset 1;
```
结果

```
id          name        phone     
----------  ----------  ----------
10005       Lucy        unknown 
```

### 函数 & 聚合

SQLite内置和许多函数，比如绝对值abs,大小写转换upper/lower。

比如
 
```
sqlite> select upper(name) from person limit 2;
upper(name)
-----------
LEO        
LINA        
```

还有一类特殊的函数是聚合函数，包括：sum,count,min,max,avg。

比如，查询数据库中行数

```
sqlite> select count(*) from person;
count(*)  
----------
9  
```

### group & having

聚合的主要作用是在分组上面，也就是group关键字。group关键字后跟着列名。举个例子：

```
id          name        phone     
----------  ----------  ----------
10001       Leo         1234578901
10002       Lina        unknown   
10003       Tom         unknown   
10004       Lily        unknown   
10005       Lucy        unknown   
10006       Jone        unknown   
10007       Kobe        unknown   
10008       Jeccy       unknown   
10009       Smith       1234567890
```
这是数据，假如按照phone分组，phone一样的行都会被分到一组里，一共分为三组，然后用count就可以统计出每组数据的数量了。

```
sqlite> select phone,count(*) from person group by phone;
phone        count(*)  
-----------  ----------
12345678902  1         
1234578901   1         
unknown      
```

之前的where是对行进行过滤，而having是对分组后的一组数据进行过滤。比如

```
sqlite> select phone,count(*) from person group by phone having count(*) > 1;
phone       count(*)  
----------  ----------
unknown     7  
```

### 内链接

以上的select都是在一个表上进行的操作，而实际应用中，我们经常需要在两个表上操作。

假设我们还有一个teacher的表:

```
create table teacher(id integer primary key,
class text not null,
course text,
person_id integer not null,
foreign key(person_id) references person(id));
```

> 这里teacher有个外键指向person的id，意味着只有在person中存在的id，才能被插入到teacher表中。从逻辑上也很容易理解，只有一个人才有可能是老师。

默认SQLite的外键约束是关闭的，需要手动开启：

```
PRAGMA FOREIGN_KEYS=ON;
```

然后，我们向teacher表中插入一些数据后，

```
id          class       course      person_id 
----------  ----------  ----------  ----------
1           grade1      math        10001     
2           grade1      science     10002     
3           grade2      chinese     10003  
```

这时候，我想知道所有教一年级的老师的名字和电话，我就需要链接查询两个表。

> 内链接就是通过表中的两个字段进行连接，是最常见或者说最有用的连接。它回答的问题是B中有哪些行匹配A中的关系：

举例：

```
sqlite> select person.name,teacher.class from person inner join teacher on person.id=teacher.person_id;
name        class     
----------  ----------
Leo         grade1    
Lina        grade1    
Tom         grade2 
```

### 外连接

> 内链接根据指定关系选择表中的行。外连接则是在内链接的基础上，外加一些关系之外的行。

外连接分为三种：左外连接，右外连接，和全外连接。

以左外连接为例：

```
select person.name,teacher.class from person left outer join teacher on person.id=teacher.person_id;
name        class     
----------  ----------
Amanda                
Jeccy                 
Jone                  
Jonese                
Kobe                  
Leo         grade1    
Lily                  
Lina        grade1    
Lucy                  
Smith                 
Tom         grade2
```

可以看到，在结果集中，除了内链接的所有结果，还包括了左表（person）的所有行。对应右表无法提供结果以null返回。

右外连接的原理类似，只不过额外的数据是右表。而全外连接则是左右外连接的结合。

> SQLite不支持右链接和全链接。但是都可以“曲线救国”，通过左链接来实现。

## 索引


有如下查询：

```
select * from person where name='Leo'
```

在实际查询的时候，SQLite会逐行扫描所有的行，然后取匹配`name='Leo'` 这个条件。当表很大的时候，这个查询会非常慢。

> 数据库索引是对数据库中一个或者多个列进行排序的数据结构，SQLite采用B-tree。  
> 优点：提高数据检索速度；  
> 缺点：增加物理磁盘空间；在数据库创建和修改数据的时候需要额外的时间去维护索引。

创建一个索引：

```
create index index_name on person(name);
```

查看索引（命令行）:

```
.schema person
CREATE TABLE person(id integer primary key,name text not null,phone text not null default 'unknown');
CREATE INDEX index_name on person(name);
```

删除索引

```
drop index index_name
```

## 事务

> 事务定义了一组SQL命令的边界，这组命令要么都执行，要么都不执行。

理解事务有一个很典型的例子：银行把用户A的钱转账到用户B的账户里。这个过程需要两步数据库操作：

- 减少用户A账户里的钱
- 增加用户B账户的钱

假如第一步成功了，而第二步失败了，那么这笔钱就凭空消失了。

当把这两个操作包装到一个事务的时候，第二步失败后，第一步会自动回滚，保证原子性。

使用事务：

```
begin
//SQL
commit
```

除了保证操作的原子性，**事务还能大幅度的提高数据库的写入速度**。

> Tips: 在不显式指明事务的时候，SQLite的每一个SQL会隐式创建一个事务。

## 视图

> 视图是虚表，是从一个或几个基本表（或视图）中导出的表，在系统的数据字典中仅存放了视图的定义，不存放视图对应的数据。  
> 优点：简化对数据的理解和操作；限制用户访问权限。

举个简单的例子，在上文我们对两个表进行了join。

```
select person.name,teacher.class from person left outer join teacher on person.id=teacher.person_id;
```

假如说我想要操作这个join的结果，每次我都要去写一遍这么长的select语句，这是很繁琐的。

而创建一个视图后：

```
sqlite> create view teacher_detail as 
   ...> select person.name,teacher.class from person left outer join teacher on person.id=teacher.person_id;
```

我就可以直接按照表的方式操作这个视图了：

```
select * from teacher_detail where name='Leo';
name        class     
----------  ----------
Leo         grade1   
```

### 其他常用数据库操作

> 相比于select，其他的数据库操作就比较简单，而且容易理解。

## insert

insert命令用作向表中插入数据，通常格式如下：

```
insert into table (column_list) values(value_list)
```

其中，column_list表示列名（多个以逗号分开），value_list表示值（多个以逗号隔开）

比如，上文我们用到的

```
insert into person (id,name,phone) values(10001,'Leo','1234578901');
```

> 当column_list为表的全部列名称，并且和创建表时候的列顺序一致，那么column_list可以省略。

```
//id,name,phone
insert into person values(10012,'Boboka','123112893218');
```

> values中的数据可以是子查询。

比如：

```
insert into person values((select max(id) from person)+1,'Clark','1232893218');
```

## update

insert命令用来更新表中的数据，通常格式如下：

```
update table_name set update_list where predicate
```
其中，update_list是以逗号分隔的多个赋值语句，where和select中的where一致。

比如：

```
update person set phone='1213124123' where id=10001;
```


## delete

insert命令用来删除表中的行，格式如下：

```
delete from table_name where perdicate
```

where的格式也和Select一致

```
delete from person where person.id=10014;
```

## 总结

作为SQLite三部曲的开篇，本文回顾了常用的SQLite操作语句，以及一些数据库的基本概念，希望对那些数据库基础薄弱的同学有些帮助。