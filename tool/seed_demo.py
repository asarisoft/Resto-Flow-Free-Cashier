"""Buat tool/seed_demo.sql: data contoh untuk emulator (screenshot/video).
JANGAN dipakai di HP pengguna. Pakai: python3 tool/seed_demo.py lalu lihat README di bawah file SQL."""
import random, time
random.seed(7)
now = int(time.time()); day = 86400
prods = [  # nama, kategori, harga, hpp
 ("Nasi Goreng","Makanan",15000,10000),("Es Jeruk","Minuman",10000,8000),
 ("Mie Ayam","Makanan",13000,7000),("Ayam Geprek","Makanan",17000,10000),
 ("Soto Ayam","Makanan",15000,8500),("Nasi Telur","Makanan",10000,5500),
 ("Es Teh","Minuman",4000,1200),("Kopi Hitam","Minuman",5000,1800),
 ("Jus Alpukat","Minuman",12000,6500),("Teh Hangat","Minuman",4000,1000)]
keep = {"Nasi Goreng":"1795531643579291","Es Jeruk":"1795531663219671"}
out = ["BEGIN;","DELETE FROM transaction_items;","DELETE FROM transactions;","DELETE FROM expenses;",
 "DELETE FROM products WHERE id NOT IN ('%s');" % "','".join(keep.values())]
pid = {}
for i,(n,c,p,h) in enumerate(prods):
    if n in keep:
        pid[n]=keep[n]; out.append(f"UPDATE products SET price={p},hpp={h} WHERE id='{keep[n]}';"); continue
    pid[n]=f"demo{i:02d}"
    out.append(f"INSERT INTO products(id,name,category,price,hpp,ready,archived,created_at,updated_at) VALUES('{pid[n]}','{n}','{c}',{p},{h},1,0,{now-20*day},{now-20*day});")
for cat in ("Sewa","Listrik","Bahan"):
    out.append(f"INSERT OR IGNORE INTO categories(id,type,name,created_at) VALUES('demo_{cat}','expense','{cat}',{now-20*day});")
num = 0
for d in range(13,-1,-1):
    base = now - d*day
    for _ in range(random.randint(8,16)):
        num += 1; tid=f"demotx{num:04d}"; ts = base - random.randint(600, 10*3600)
        items = random.sample(prods, random.randint(1,3)); sub=prof=0; rows=[]
        for n,c,p,h in items:
            q=random.randint(1,3); sub+=p*q; prof+=(p-h)*q
            rows.append(f"INSERT INTO transaction_items(transaction_id,product_id,name,price,hpp,qty) VALUES('{tid}','{pid[n]}','{n}',{p},{h},{q});")
        pm = random.choice(["cash","cash","qris"]); paid = sub if pm=="qris" else -(-sub//5000)*5000
        out.append(f"INSERT INTO transactions(id,number,subtotal,total,paid,change,payment_method,profit,status,created_at) VALUES('{tid}',{num},{sub},{sub},{paid},{paid-sub},'{pm}',{prof},'paid',{ts});")
        out += rows
for i,(cat,note,amt,d) in enumerate([("Sewa","Sewa tempat",1500000,12),("Listrik","Token listrik",200000,9),("Bahan","Gas & plastik",150000,5),("Listrik","Token listrik",100000,1)]):
    out.append(f"INSERT INTO expenses(id,category,note,amount,date,created_at) VALUES('demoexp{i}','{cat}','{note}',{amt},{now-d*day},{now-d*day});")
out.append(f"INSERT OR REPLACE INTO counters(key,value) VALUES('receipt',{num});")
out.append("COMMIT;")
open("tool/seed_demo.sql","w").write("\n".join(out)+"\n")
print("transaksi:",num)
