# Генератор файла geosite.dat (dlc.dat)
## Как использовать?
1. Сделайте форк репозитория v2fly (https://github.com/v2fly/domain-list-community)
2. Добавьте в папку data сайты которые вам нужны. Например: Создаёте файл vk, в нем прописываете домены vk, Сохраняете и публикуете изменения.
## Важно! При удалении каких либо файлов из папки data, скрипт перестает работать и выдаёт ошибку, это временный баг.
3. Скачайте и запустите скрипт: 
```bash
sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/makdren/geosite-generator/main/dlcgen.sh)"
```
Файлы будут созданы в:

```
/root/dlcgen/
```