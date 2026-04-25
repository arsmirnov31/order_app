# Вместо from .utils ...
from utils import generate_excel, format_date, build_report_data, normalize_product_name, parse_sheet, parse_excel

from pathlib import Path
import openpyxl
import re

# Укажите полный путь к файлу
file_path = Path(r'/tmp/order_old.xlsx')

wb = parse_excel(file_path)   
print(wb)