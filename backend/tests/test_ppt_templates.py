import importlib.util,tempfile,unittest
from pathlib import Path
from pptx import Presentation
spec=importlib.util.spec_from_file_location('ppt_template',Path(__file__).resolve().parents[1]/'ppt-template.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
class Templates(unittest.TestCase):
 def test_selected_sections_and_pagination(self):
  with tempfile.TemporaryDirectory() as d:
   path=Path(d)/'test.pptx'
   module.build({'organization':{'name':'QA'},'template':{'include_cover':False,'sections':['risks'],'body_font_size':24,'lines_per_slide':6},'risks':[{'title':f'Risco {i} '+('Texto completo '*40)} for i in range(15)],'decisions':[{'title':'NAO_INCLUIR'}]},path)
   deck=Presentation(path);texts='\n'.join(shape.text for slide in deck.slides for shape in slide.shapes if shape.has_text_frame)
   self.assertNotIn('NAO_INCLUIR',texts);self.assertNotIn('Plano Estratégico',texts)
   for i in range(15): self.assertIn(f'Risco {i} ',texts)
   self.assertGreater(len(deck.slides),15)
 def test_empty_selection_has_readable_slide(self):
  with tempfile.TemporaryDirectory() as d:
   path=Path(d)/'test.pptx';module.build({'template':{'include_cover':False,'sections':['swot']}},path)
   self.assertEqual(len(Presentation(path).slides),1)
if __name__=='__main__':unittest.main()
