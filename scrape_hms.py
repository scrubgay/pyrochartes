# code mostly imported from auctions-scraper

from playwright.sync_api import sync_playwright, expect
import requests
import time # rate-limiting functions
import re

url = r"https://www.ospo.noaa.gov/Products/land/hms.html#data"

def save_txt(link:str, out_dir:str=r"data/") :
    print("Downloading " + link)
    file = requests.get(link)
    filename = re.split("/", link)
    filename = filename[len(filename)-1]
    with open(out_dir + filename, 'w') as f :
        f.write(file.text)

def generate_url(mdy:str) :
    template = "https://satepsanone.nesdis.noaa.gov/pub/FIRE/web/HMS/Fire_Points/Text/2024/01/hms_fire20240131.txt"
    date_components = re.split("(/|-)", mdy) # month = 1

def scrape_page(from_date:str, to_date:str) :
    with sync_playwright() as p :
        browser = p.firefox.launch()
        page = browser.new_page()
        page.set_default_timeout(90000)

        links = []

        try :
            page.goto(url)
            
            sat = page.locator("#sats")
            expect(sat).to_be_visible()
            if sat.is_visible() :
                sat.select_option("fire")

            file_type = page.locator("#d2 > select")
            expect(file_type).to_be_visible()
            if file_type.is_visible() :
                file_type.select_option("Text")

            from_sel = page.locator("#from")
            expect(from_sel).to_be_visible()
            if from_sel.is_visible() :
                from_sel.fill(from_date)

            to_sel = page.locator("#to")
            expect(to_sel).to_be_visible()
            if to_sel.is_visible() :
                to_sel.fill(to_date)
            to_sel.press("Tab")

            data = page.locator("#demo")
            expect(data.first).to_be_visible()
            if data.first.is_visible() :
                a_s = page.locator("#demo > a").all()
                for a in a_s :
                    links.append(a.get_attribute("href"))
            
            for link in links :
                save_txt(link)

        except Exception as e :
            print("There was an error:")
            print(e)
        browser.close()
    
scrape_page("10/23/2023", "02/18/2024")