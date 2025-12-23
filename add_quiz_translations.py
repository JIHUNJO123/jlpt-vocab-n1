import json
import os
from openai import OpenAI

# API 키는 환경변수 또는 직접 입력
client = OpenAI(api_key=os.environ.get('OPENAI_API_KEY', 'YOUR_API_KEY_HERE'))

def translate_synonyms():
    """synonyms.json에 영어/중국어 번역 추가"""
    with open('assets/data/synonyms.json', 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    print(f"Total synonym pairs: {len(data)}")
    
    # 배치로 번역 (10개씩)
    batch_size = 10
    for i in range(0, len(data), batch_size):
        batch = data[i:i+batch_size]
        print(f"\nProcessing synonyms {i+1}-{min(i+batch_size, len(data))}...")
        
        # 번역할 텍스트 준비
        texts_to_translate = []
        for item in batch:
            texts_to_translate.append({
                "meaning1_ko": item['meaning1_ko'],
                "meaning2_ko": item['meaning2_ko'],
                "explanation_ko": item['explanation_ko']
            })
        
        prompt = f"""Translate these Japanese vocabulary quiz items from Korean to English and Chinese.
Keep translations concise and natural for vocabulary learning.

Input (Korean):
{json.dumps(texts_to_translate, ensure_ascii=False, indent=2)}

Return JSON array with same structure, adding _en and _zh versions:
[
  {{
    "meaning1_en": "...",
    "meaning1_zh": "...",
    "meaning2_en": "...",
    "meaning2_zh": "...",
    "explanation_en": "...",
    "explanation_zh": "..."
  }},
  ...
]

Rules:
- Keep explanations short and clear
- Use common/simple English words
- Use Simplified Chinese (简体中文)
- Return ONLY the JSON array, no other text"""

        try:
            response = client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.3
            )
            
            result_text = response.choices[0].message.content.strip()
            # JSON 추출
            if result_text.startswith("```"):
                result_text = result_text.split("```")[1]
                if result_text.startswith("json"):
                    result_text = result_text[4:]
            
            translations = json.loads(result_text)
            
            # 원본 데이터에 번역 추가
            for j, trans in enumerate(translations):
                idx = i + j
                if idx < len(data):
                    data[idx]['meaning1_en'] = trans.get('meaning1_en', '')
                    data[idx]['meaning1_zh'] = trans.get('meaning1_zh', '')
                    data[idx]['meaning2_en'] = trans.get('meaning2_en', '')
                    data[idx]['meaning2_zh'] = trans.get('meaning2_zh', '')
                    data[idx]['explanation_en'] = trans.get('explanation_en', '')
                    data[idx]['explanation_zh'] = trans.get('explanation_zh', '')
            
            print(f"  Translated {len(translations)} items")
            
        except Exception as e:
            print(f"  Error: {e}")
            # 오류 시 기본값 설정
            for j in range(len(batch)):
                idx = i + j
                if idx < len(data):
                    data[idx]['meaning1_en'] = data[idx]['meaning1_ko']
                    data[idx]['meaning1_zh'] = data[idx]['meaning1_ko']
                    data[idx]['meaning2_en'] = data[idx]['meaning2_ko']
                    data[idx]['meaning2_zh'] = data[idx]['meaning2_ko']
                    data[idx]['explanation_en'] = data[idx]['explanation_ko']
                    data[idx]['explanation_zh'] = data[idx]['explanation_ko']
    
    # 저장
    with open('assets/data/synonyms.json', 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    
    print(f"\nSynonyms translation complete!")
    return data

def translate_collocations():
    """collocations.json에 영어/중국어 번역 추가"""
    with open('assets/data/collocations.json', 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    print(f"\nTotal collocations: {len(data)}")
    
    # 배치로 번역 (10개씩)
    batch_size = 10
    for i in range(0, len(data), batch_size):
        batch = data[i:i+batch_size]
        print(f"\nProcessing collocations {i+1}-{min(i+batch_size, len(data))}...")
        
        # 번역할 텍스트 준비
        texts_to_translate = []
        for item in batch:
            texts_to_translate.append({
                "noun_meaning_ko": item['noun_meaning_ko'],
                "correct_verb_meaning_ko": item['correct_verb_meaning_ko'],
                "meaning_ko": item['meaning_ko']
            })
        
        prompt = f"""Translate these Japanese collocation quiz items from Korean to English and Chinese.
Keep translations concise and natural for vocabulary learning.

Input (Korean):
{json.dumps(texts_to_translate, ensure_ascii=False, indent=2)}

Return JSON array with same structure, adding _en and _zh versions:
[
  {{
    "noun_meaning_en": "...",
    "noun_meaning_zh": "...",
    "correct_verb_meaning_en": "...",
    "correct_verb_meaning_zh": "...",
    "meaning_en": "...",
    "meaning_zh": "..."
  }},
  ...
]

Rules:
- Keep explanations short and clear
- Use common/simple English words
- Use Simplified Chinese (简体中文)
- Return ONLY the JSON array, no other text"""

        try:
            response = client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[{"role": "user", "content": prompt}],
                temperature=0.3
            )
            
            result_text = response.choices[0].message.content.strip()
            # JSON 추출
            if result_text.startswith("```"):
                result_text = result_text.split("```")[1]
                if result_text.startswith("json"):
                    result_text = result_text[4:]
            
            translations = json.loads(result_text)
            
            # 원본 데이터에 번역 추가
            for j, trans in enumerate(translations):
                idx = i + j
                if idx < len(data):
                    data[idx]['noun_meaning_en'] = trans.get('noun_meaning_en', '')
                    data[idx]['noun_meaning_zh'] = trans.get('noun_meaning_zh', '')
                    data[idx]['correct_verb_meaning_en'] = trans.get('correct_verb_meaning_en', '')
                    data[idx]['correct_verb_meaning_zh'] = trans.get('correct_verb_meaning_zh', '')
                    data[idx]['meaning_en'] = trans.get('meaning_en', '')
                    data[idx]['meaning_zh'] = trans.get('meaning_zh', '')
            
            print(f"  Translated {len(translations)} items")
            
        except Exception as e:
            print(f"  Error: {e}")
            # 오류 시 기본값 설정
            for j in range(len(batch)):
                idx = i + j
                if idx < len(data):
                    data[idx]['noun_meaning_en'] = data[idx]['noun_meaning_ko']
                    data[idx]['noun_meaning_zh'] = data[idx]['noun_meaning_ko']
                    data[idx]['correct_verb_meaning_en'] = data[idx]['correct_verb_meaning_ko']
                    data[idx]['correct_verb_meaning_zh'] = data[idx]['correct_verb_meaning_ko']
                    data[idx]['meaning_en'] = data[idx]['meaning_ko']
                    data[idx]['meaning_zh'] = data[idx]['meaning_ko']
    
    # 저장
    with open('assets/data/collocations.json', 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    
    print(f"\nCollocations translation complete!")
    return data

if __name__ == '__main__':
    translate_synonyms()
    translate_collocations()
    print("\n=== All translations complete! ===")
