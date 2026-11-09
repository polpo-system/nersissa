MODULE NersissaTest;  (* the panel of Nersissa: its lists filled from portia's tree, a category chosen,
  a package described; nothing is installed or removed *)

IMPORT Objects, Documents, Gadgets, Attributes, Lists, TextGadgets0, Texts, Out, portia, Nersissa;

TYPE
  Name = ARRAY 64 OF CHAR;

VAR
  checks, fails: LONGINT;

PROCEDURE Check(what: ARRAY OF CHAR; ok: BOOLEAN);
BEGIN
  INC(checks);
  IF ~ok THEN INC(fails); Out.String("FAIL "); Out.String(what); Out.String(" (case "); Out.Int(checks, 0); Out.String(")"); Out.Ln END
END Check;

PROCEDURE Append(VAR s: ARRAY OF CHAR; t: ARRAY OF CHAR);
VAR i, j: INTEGER;
BEGIN
  i := 0; WHILE s[i] # 0X DO INC(i) END;
  j := 0; WHILE (t[j] # 0X) & (i < LEN(s) - 1) DO s[i] := t[j]; INC(i); INC(j) END;
  s[i] := 0X
END Append;

PROCEDURE Count(L: Lists.List): LONGINT;
VAR it: Lists.Item; n: LONGINT;
BEGIN n := 0; it := L.items; WHILE it # NIL DO INC(n); it := it.next END; RETURN n
END Count;

PROCEDURE Starts(VAR s: ARRAY OF CHAR; t: ARRAY OF CHAR): BOOLEAN;
VAR i: INTEGER;
BEGIN i := 0; WHILE (t[i] # 0X) & (s[i] = t[i]) DO INC(i) END; RETURN t[i] = 0X
END Starts;

PROCEDURE Item(L: Lists.List; prefix: ARRAY OF CHAR): Lists.Item;  (* the first item that starts with prefix *)
VAR it: Lists.Item;
BEGIN it := L.items; WHILE (it # NIL) & ~Starts(it.s, prefix) DO it := it.next END; RETURN it
END Item;

PROCEDURE FirstLine(T: Texts.Text; VAR s: ARRAY OF CHAR);
VAR R: Texts.Reader; ch: CHAR; i: INTEGER;
BEGIN
  Texts.OpenReader(R, T, 0); Texts.Read(R, ch); i := 0;
  WHILE ~R.eot & (ch # 0DX) & (i < LEN(s) - 1) DO s[i] := ch; INC(i); Texts.Read(R, ch) END;
  s[i] := 0X
END FirstLine;

PROCEDURE Run*;
VAR D: Documents.Document; P, obj: Objects.Object; cats, pkgs: Lists.List; it: Lists.Item;
  total, n, incat: LONGINT; name, cat, version, inst, c, v, i2, s, want, caption: Name; desc: ARRAY 256 OF CHAR;
  inBase, remote: BOOLEAN;
BEGIN
  checks := 0; fails := 0;
  Nersissa.NewDoc; D := Objects.NewObj(Documents.Document); Check("the document", D # NIL);
  P := D.dsc;
  obj := Gadgets.FindObj(P, "Categories"); Check("the list of categories", (obj # NIL) & (obj IS Lists.List));
  cats := obj(Lists.List);
  obj := Gadgets.FindObj(P, "Packages"); Check("the list of packages", (obj # NIL) & (obj IS Lists.List));
  pkgs := obj(Lists.List);
  total := 0; WHILE portia.GetPackage(total, name, cat, version, inst, desc, inBase, remote) DO INC(total) END;
  Check("a package tree", total > 0);
  Check("all packages listed at first", Count(pkgs) = total);
  Check("all, installed, upgradable first", Starts(cats.items.s, "all (") & Starts(cats.items.next.s, "installed (")
    & Starts(cats.items.next.next.s, "upgradable ("));

  (* the category of the first package of the tree, chosen as by a middle click *)
  IF portia.GetPackage(0, name, cat, version, inst, desc, inBase, remote) THEN
    s := cat; Append(s, " ("); it := Item(cats, s); Check("its category listed", it # NIL);
    IF it # NIL THEN
      cats.pointed := it; Gadgets.executorObj := cats; Gadgets.context := P; Nersissa.Category;
      incat := 0; n := 0;
      WHILE portia.GetPackage(n, s, c, v, i2, desc, inBase, remote) DO IF c = cat THEN INC(incat) END; INC(n) END;
      Check("the packages of the category", Count(pkgs) = incat);
      Check("the category selected", it.sel)
    END;

    (* the package, chosen as by a middle click *)
    IF inst = "" THEN want := "[ ] " ELSIF inst # version THEN want := "[u] " ELSE want := "[x] " END;
    Append(want, name); Append(want, "  ");
    it := Item(pkgs, want); Check("the package listed with its state", it # NIL);
    IF it # NIL THEN
      pkgs.pointed := it; Gadgets.executorObj := pkgs; Gadgets.context := P; Nersissa.Package;
      Attributes.GetString(Gadgets.FindObj(P, "Status"), "Value", s);
      Check("the state of the package", Starts(s, name));
      obj := Gadgets.FindObj(P, "Details");
      IF (obj # NIL) & (obj IS TextGadgets0.Frame) THEN
        FirstLine(obj(TextGadgets0.Frame).text, s);
        want := name; Append(want, " "); Append(want, version);
        Check("its description", s = want)
      ELSE Check("the description", FALSE)
      END;
      Attributes.GetString(Gadgets.FindObj(P, "Action"), "Caption", caption);
      IF inst = "" THEN Check("the button installs", caption = "Install") ELSE Check("the button removes", caption = "Remove") END
    END
  END;
  Out.String("NersissaTest: "); Out.Int(checks, 0); Out.String(" checks, "); Out.Int(fails, 0); Out.String(" failed"); Out.Ln
END Run;

END NersissaTest.
