MODULE Nersissa;  (** the packages of portia in a panel: categories at the left, the packages of the chosen
  one at the upper right, the description of the chosen package below; Install or Remove, Upgrade, Sync *)

(* Nersissa.Open shows the panel in a viewer of the desktop, or, run from the shell (loksh Nersissa.Open), in
  a window of its own. A middle click on a category lists its packages, a middle click on a package shows
  its description; the buttons act on that package through portia's commands (portia.Install /y,
  portia.Remove /y), whose messages go to System.Log. In the lists, [x] is an installed package, [ ] one
  that is not, [u] one with a newer version in the tree. *)

IMPORT Modules, Objects, Display, Texts, Oberon, Out, Gadgets, Attributes, Panels, Documents, PanelDocs, Desktops,
  DocWindows, Windows, Lists, TextGadgets0, Versions, portia;

CONST
  All = "all"; Installed = "installed"; Upgradable = "upgradable";  (* the categories that are not portia's *)
  MaxCats = 64;

TYPE
  Name = ARRAY 64 OF CHAR;

VAR
  category, current: Name;  (* the category listed, the package described *)
  W: Texts.Writer;  (* the description *)
  skip: BOOLEAN;  (* Catch leaves out the first line of portia.Describe, which says what the description says *)

(* --- the panel --- *)

(* a new gadget made by its generator, w x h, at x, y of the panel (from its top left corner; y counts down) *)
PROCEDURE Add(P: Panels.Panel; gen: ARRAY OF CHAR; name: ARRAY OF CHAR; x, y, w, h: INTEGER): Display.Frame;
VAR obj: Objects.Object; F: Display.Frame;
BEGIN
  obj := Gadgets.CreateObject(gen); F := obj(Display.Frame);
  F.W := w; F.H := h;
  Panels.InsertChild(P, F, x, y - h);
  IF name # "" THEN Gadgets.NameObj(F, name) END;
  RETURN F
END Add;

PROCEDURE Button(P: Panels.Panel; name, caption, cmd: ARRAY OF CHAR; x, y, w: INTEGER);
VAR F: Display.Frame;
BEGIN
  F := Add(P, "BasicGadgets.NewButton", name, x, y, w, 28);
  Attributes.SetString(F, "Caption", caption); Attributes.SetString(F, "Cmd", cmd)
END Button;

PROCEDURE Caption(P: Panels.Panel; text: ARRAY OF CHAR; x, y: INTEGER);
VAR F: Display.Frame;
BEGIN
  F := Add(P, "TextFields.NewCaption", "", x, y, 100, 20); Attributes.SetString(F, "Value", text)
END Caption;

PROCEDURE ListOf(P: Panels.Panel; name, cmd: ARRAY OF CHAR; x, y, w, h: INTEGER);
VAR F: Display.Frame;
BEGIN
  F := Add(P, "Lists.NewList", name, x, y, w, h);
  F(Lists.List).sorted := FALSE; Attributes.SetString(F, "Cmd", cmd)
END ListOf;

PROCEDURE Find(context: Objects.Object; name: ARRAY OF CHAR): Objects.Object;
BEGIN RETURN Gadgets.FindObj(context, name)
END Find;

PROCEDURE Clear(L: Lists.List);
BEGIN L.items := NIL; L.last := NIL; L.beg := NIL; L.pointed := NIL; L.noitems := 0
END Clear;

PROCEDURE SetText(obj: Objects.Object; attr, s: ARRAY OF CHAR);
BEGIN
  IF obj # NIL THEN Attributes.SetString(obj, attr, s); Gadgets.Update(obj) END
END SetText;

(* --- the packages --- *)

PROCEDURE Upgr(VAR inst, version: ARRAY OF CHAR): BOOLEAN;  (* installed, a newer version in the tree *)
BEGIN RETURN (inst # "") & ~Versions.AtLeast(inst, version)
END Upgr;

PROCEDURE Shown(VAR cat, pcat, inst, version: ARRAY OF CHAR): BOOLEAN;  (* the package in category cat *)
BEGIN
  IF cat = All THEN RETURN TRUE
  ELSIF cat = Installed THEN RETURN inst # ""
  ELSIF cat = Upgradable THEN RETURN Upgr(inst, version)
  ELSE RETURN pcat = cat
  END
END Shown;

PROCEDURE Append(VAR s: ARRAY OF CHAR; t: ARRAY OF CHAR);
VAR i, j: LONGINT;
BEGIN
  i := 0; WHILE s[i] # 0X DO INC(i) END;
  j := 0; WHILE (t[j] # 0X) & (i < LEN(s) - 1) DO s[i] := t[j]; INC(i); INC(j) END;
  s[i] := 0X
END Append;

PROCEDURE AppendInt(VAR s: ARRAY OF CHAR; n: LONGINT);
VAR d: ARRAY 12 OF CHAR; k: INTEGER; t: ARRAY 2 OF CHAR;
BEGIN
  k := 0; REPEAT d[k] := CHR(n MOD 10 + ORD("0")); n := n DIV 10; INC(k) UNTIL n = 0;
  t[1] := 0X; WHILE k > 0 DO DEC(k); t[0] := d[k]; Append(s, t) END
END AppendInt;

(* the word of a list item: the category before " (", the package after "] " *)
PROCEDURE Word(VAR item: ARRAY OF CHAR; package: BOOLEAN; VAR w: ARRAY OF CHAR);
VAR i, j: INTEGER;
BEGIN
  i := 0;
  IF package THEN WHILE (item[i] # 0X) & (item[i] # "]") DO INC(i) END; IF item[i] = "]" THEN INC(i, 2) END END;
  j := 0; WHILE (item[i] > " ") & (j < LEN(w) - 1) DO w[j] := item[i]; INC(i); INC(j) END;
  w[j] := 0X
END Word;

(* the categories: all, installed, upgradable, then those of the tree in alphabetical order, with their counts *)
PROCEDURE FillCategories(L: Lists.List);
VAR cats: ARRAY MaxCats OF Name; counts: ARRAY MaxCats OF LONGINT; ncats, n, i, k, nall, ninst, nupgr: LONGINT;
  name, cat, version, inst, item: Name; desc: ARRAY 256 OF CHAR; inBase, remote: BOOLEAN;
BEGIN
  ncats := 0; nall := 0; ninst := 0; nupgr := 0; n := 0;
  WHILE portia.GetPackage(n, name, cat, version, inst, desc, inBase, remote) DO
    INC(nall); IF inst # "" THEN INC(ninst) END; IF Upgr(inst, version) THEN INC(nupgr) END;
    i := 0; WHILE (i < ncats) & (cats[i] # cat) DO INC(i) END;
    IF i < ncats THEN INC(counts[i])
    ELSIF ncats < MaxCats THEN  (* in order *)
      k := ncats; WHILE (k > 0) & (cats[k - 1] > cat) DO cats[k] := cats[k - 1]; counts[k] := counts[k - 1]; DEC(k) END;
      COPY(cat, cats[k]); counts[k] := 1; INC(ncats)
    END;
    INC(n)
  END;
  Clear(L);
  item := All; Append(item, " ("); AppendInt(item, nall); Append(item, ")"); Lists.InsertItem(L, item);
  item := Installed; Append(item, " ("); AppendInt(item, ninst); Append(item, ")"); Lists.InsertItem(L, item);
  item := Upgradable; Append(item, " ("); AppendInt(item, nupgr); Append(item, ")"); Lists.InsertItem(L, item);
  i := 0;
  WHILE i < ncats DO
    COPY(cats[i], item); Append(item, " ("); AppendInt(item, counts[i]); Append(item, ")"); Lists.InsertItem(L, item);
    INC(i)
  END;
  Gadgets.Update(L)
END FillCategories;

PROCEDURE Select(L: Lists.List; VAR w: ARRAY OF CHAR; package: BOOLEAN);  (* the item of the word w selected *)
VAR it: Lists.Item; s: Name;
BEGIN
  it := L.items;
  WHILE it # NIL DO Word(it.s, package, s); it.sel := s = w; it := it.next END
END Select;

PROCEDURE FillPackages(L: Lists.List);
VAR n: LONGINT; name, cat, version, inst, item: Name; desc: ARRAY 256 OF CHAR; inBase, remote: BOOLEAN;
BEGIN
  Clear(L); n := 0;
  WHILE portia.GetPackage(n, name, cat, version, inst, desc, inBase, remote) DO
    IF Shown(category, cat, inst, version) THEN
      IF Upgr(inst, version) THEN item := "[u] " ELSIF inst # "" THEN item := "[x] " ELSE item := "[ ] " END;
      Append(item, name); Append(item, "  ");
      IF Upgr(inst, version) THEN Append(item, inst); Append(item, " > ") END;
      Append(item, version);
      Lists.InsertItem(L, item)
    END;
    INC(n)
  END;
  Select(L, current, TRUE);
  Gadgets.Update(L)
END FillPackages;

(* Out of portia.Describe into W *)
PROCEDURE Catch(VAR s: ARRAY OF CHAR; len: LONGINT);
VAR i: LONGINT;
BEGIN
  i := 0;
  WHILE i < len DO
    IF skip THEN skip := s[i] # 0AX ELSIF s[i] = 0AX THEN Texts.WriteLn(W) ELSE Texts.Write(W, s[i]) END;
    INC(i)
  END
END Catch;

(* the description of the package current, the state, and the caption of the button Action *)
PROCEDURE Describe(context: Objects.Object);
VAR obj: Objects.Object; T: Texts.Text; n: LONGINT; name, cat, version, inst, state: Name; desc: ARRAY 256 OF CHAR;
  inBase, remote, found: BOOLEAN; save: Out.Writer;
BEGIN
  n := 0; found := FALSE;
  WHILE ~found & portia.GetPackage(n, name, cat, version, inst, desc, inBase, remote) DO found := name = current; INC(n) END;
  obj := Find(context, "Details");
  IF (obj # NIL) & (obj IS TextGadgets0.Frame) THEN
    T := obj(TextGadgets0.Frame).text;
    IF found THEN
      Texts.WriteString(W, name); Texts.Write(W, " "); Texts.WriteString(W, version); Texts.WriteLn(W);
      Texts.WriteString(W, desc); Texts.WriteLn(W); Texts.WriteLn(W);
      IF inst = "" THEN Texts.WriteString(W, "not installed")
      ELSE Texts.WriteString(W, "installed: "); Texts.WriteString(W, inst);
        IF Upgr(inst, version) THEN Texts.WriteString(W, ", ") ; Texts.WriteString(W, version); Texts.WriteString(W, " in the tree") END
      END;
      IF inBase THEN Texts.WriteString(W, "; part of the base system") END;
      Texts.WriteLn(W); Texts.WriteLn(W);
      skip := TRUE; save := Out.writer; Out.writer := Catch; portia.Describe(name); Out.writer := save
    END;
    Texts.Delete(T, 0, T.len); Texts.Append(T, W.buf)
  END;
  IF ~found THEN state := ""
  ELSE
    COPY(name, state); Append(state, ": ");
    IF inst = "" THEN Append(state, "not installed")
    ELSIF Upgr(inst, version) THEN Append(state, "installed "); Append(state, inst); Append(state, ", can be upgraded")
    ELSE Append(state, "installed")
    END
  END;
  SetText(Find(context, "Status"), "Value", state);
  IF found & (inst # "") THEN SetText(Find(context, "Action"), "Caption", "Remove")
  ELSE SetText(Find(context, "Action"), "Caption", "Install")
  END
END Describe;

PROCEDURE Show(context: Objects.Object);  (* the lists and the description again, after a change *)
VAR obj: Objects.Object;
BEGIN
  IF ~portia.Reload() THEN SetText(Find(context, "Status"), "Value", "no package tree: Sync downloads it"); RETURN END;
  obj := Find(context, "Categories");
  IF (obj # NIL) & (obj IS Lists.List) THEN FillCategories(obj(Lists.List)); Select(obj(Lists.List), category, FALSE) END;
  obj := Find(context, "Packages");
  IF (obj # NIL) & (obj IS Lists.List) THEN FillPackages(obj(Lists.List)) END;
  Describe(context)
END Show;

(* a command of portia with /y and the package current *)
PROCEDURE Portia(cmd: ARRAY OF CHAR);
VAR par: Oberon.ParList; T: Texts.Text; res: INTEGER;
BEGIN
  NEW(T); Texts.Open(T, "");
  Texts.WriteString(W, "/y "); Texts.WriteString(W, current); Texts.WriteLn(W); Texts.Append(T, W.buf);
  NEW(par); par.vwr := NIL; par.frame := NIL; par.obj := NIL; par.text := T; par.pos := 0;
  Oberon.Call(cmd, par, FALSE, res)
END Portia;

(* --- commands --- *)

(** Nersissa.Category  the Cmd of the list of categories: its packages *)
PROCEDURE Category*;
VAR item, w: Name; obj: Objects.Object;
BEGIN
  IF Gadgets.executorObj = NIL THEN RETURN END;
  Attributes.GetString(Gadgets.executorObj, "Point", item); Word(item, FALSE, w);
  IF w # "" THEN
    COPY(w, category);
    IF Gadgets.executorObj IS Lists.List THEN Select(Gadgets.executorObj(Lists.List), category, FALSE); Gadgets.Update(Gadgets.executorObj) END;
    obj := Find(Gadgets.context, "Packages");
    IF (obj # NIL) & (obj IS Lists.List) THEN FillPackages(obj(Lists.List)) END
  END
END Category;

(** Nersissa.Package  the Cmd of the list of packages: its description *)
PROCEDURE Package*;
VAR item, w: Name;
BEGIN
  IF Gadgets.executorObj = NIL THEN RETURN END;
  Attributes.GetString(Gadgets.executorObj, "Point", item); Word(item, TRUE, w);
  IF w # "" THEN
    COPY(w, current);
    IF Gadgets.executorObj IS Lists.List THEN Select(Gadgets.executorObj(Lists.List), current, TRUE); Gadgets.Update(Gadgets.executorObj) END;
    Describe(Gadgets.context)
  END
END Package;

(** Nersissa.Action  install the package described, or remove it when it is installed *)
PROCEDURE Action*;
VAR context: Objects.Object; caption: Name;
BEGIN
  IF current = "" THEN RETURN END;
  context := Gadgets.context;
  Attributes.GetString(Find(context, "Action"), "Caption", caption);
  IF caption = "Remove" THEN Portia("portia.Remove") ELSE Portia("portia.Install") END;
  Show(context)
END Action;

(** Nersissa.Upgrade  install the newer version of the package described *)
PROCEDURE Upgrade*;
VAR context: Objects.Object;
BEGIN
  IF current = "" THEN RETURN END;
  context := Gadgets.context; Portia("portia.Install"); Show(context)
END Upgrade;

(** Nersissa.Sync  the newest package tree (portia.Sync) *)
PROCEDURE Sync*;
VAR context: Objects.Object; par: Oberon.ParList; T: Texts.Text; res: INTEGER;
BEGIN
  context := Gadgets.context;
  NEW(T); Texts.Open(T, ""); NEW(par); par.text := T; par.pos := 0;
  Oberon.Call("portia.Sync", par, FALSE, res);
  Show(context)
END Sync;

(** Nersissa.NewDoc  the generator of the document (in Objects.NewObj, as PanelDocs.NewDoc): the panel, as
  wide as the left track of the screen, filled from the package tree *)
PROCEDURE NewDoc*;
VAR D: Documents.Document; P: Panels.Panel; F: Display.Frame; w, h, cw, x, ph: INTEGER;
BEGIN
  w := Display.Width DIV 8 * 5 - 20; IF w > 1000 THEN w := 1000 ELSIF w < 420 THEN w := 420 END;  (* the left track *)
  h := Display.Height - 140; IF h > 720 THEN h := 720 ELSIF h < 360 THEN h := 360 END;
  cw := w DIV 5; IF cw < 130 THEN cw := 130 END;  (* the categories *)
  x := cw + 20; ph := (h - 84) DIV 2;  (* the packages, their height *)
  PanelDocs.NewDoc; D := Objects.NewObj(Documents.Document);
  D.name := "Nersissa"; D.W := w; D.H := h;
  P := D.dsc(Panels.Panel); P.W := w; P.H := h;
  Button(P, "Action", "Install", "Nersissa.Action", 10, -10, 90);
  Button(P, "", "Upgrade", "Nersissa.Upgrade", 106, -10, 90);
  Button(P, "", "Sync", "Nersissa.Sync", 202, -10, 70);
  F := Add(P, "TextFields.NewTextField", "Status", 284, -10, w - 294, 28);
  Caption(P, "Categories", 10, -50);
  Caption(P, "Packages", x, -50);
  ListOf(P, "Categories", "Nersissa.Category", 10, -74, cw, h - 84);
  ListOf(P, "Packages", "Nersissa.Package", x, -74, w - x - 10, ph);
  F := Add(P, "TextGadgets.New", "Details", x, -82 - ph, w - x - 10, h - 92 - ph);
  IF category = "" THEN category := All END;
  Show(P);
  Objects.NewObj := D
END NewDoc;

(** Nersissa.Open  the panel: in a viewer of the desktop, or in a window of its own when run from the shell *)
PROCEDURE Open*;
VAR D: Documents.Document; V: Windows.Window;
BEGIN
  NewDoc; D := Objects.NewObj(Documents.Document);
  IF Modules.FindMod("System") # NIL THEN Desktops.ShowDoc(D)
  ELSE V := DocWindows.Open(D); Windows.Run(V)
  END
END Open;

BEGIN
  Texts.OpenWriter(W); category := ""; current := ""
END Nersissa.
