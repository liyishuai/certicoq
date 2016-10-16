
(******)
Add LoadPath "../common" as Common.
Add LoadPath "../L1_5_box" as L1_5.
Add LoadPath "../L2_typeStripped" as L2.
Add LoadPath "../L3_flattenedApp" as L3.
(******)

Require Import Coq.Lists.List.
Require Import Coq.Strings.String.
Require Import Coq.Strings.Ascii.
Require Import Coq.Arith.Compare_dec.
Require Import Coq.Program.Basics.
Require Import Coq.omega.Omega.
Require Import Coq.Logic.JMeq.
Require Import L3.term.
Require Import L3.program.
Require Import L3.wndEval.
Require Import L3.compile.

Local Open Scope string_scope.
Local Open Scope bool.
Local Open Scope list.
Set Implicit Arguments.

(** Relational version of weak cbv evaluation  **)
Inductive WcbvEval (p:environ Term) : Term -> Term -> Prop :=
| wPrf: WcbvEval p TProof TProof
| wLam: forall nm bod,
          WcbvEval p (TLambda nm bod) (TLambda nm bod)
| wProd: forall nm bod,
          WcbvEval p (TProd nm bod) (TProd nm bod)
| wConstruct: forall i r args args',
                WcbvEvals p args args' ->
                WcbvEval p (TConstruct i r args) (TConstruct i r args')
| wInd: forall i, WcbvEval p (TInd i) (TInd i) 
| wSort: forall s, WcbvEval p (TSort s) (TSort s)
| wFix: forall dts m, WcbvEval p (TFix dts m) (TFix dts m)
| wAx: WcbvEval p TAx TAx
| wConst: forall nm (t s:Term),
            LookupDfn nm p t -> WcbvEval p t s -> WcbvEval p (TConst nm) s
| wAppLam: forall (fn bod a1 a1' s:Term) (nm:name),
               WcbvEval p fn (TLambda nm bod) ->
               WcbvEval p a1 a1' ->
               WcbvEval p (whBetaStep bod a1') s ->
               WcbvEval p (TApp fn a1) s
| wLetIn: forall (nm:name) (dfn bod dfn' s:Term),
            WcbvEval p dfn dfn' ->
            WcbvEval p (instantiate dfn' 0 bod) s ->
            WcbvEval p (TLetIn nm dfn bod) s
| wAppFix: forall dts m (fn arg fs s:Term),
               WcbvEval p fn (TFix dts m) ->
               whFixStep dts m = Some fs ->
               WcbvEval p (TApp fs arg) s ->
               WcbvEval p (TApp fn arg) s
| wAppCong: forall fn efn arg arg1,
              WcbvEval p fn efn ->
              ~ isLambda efn -> ~ isFix efn ->
              WcbvEval p arg arg1 ->
              WcbvEval p (TApp fn arg) (TApp efn arg1)
| wCase: forall mch i n ml args args' brs cs s,
           WcbvEval p mch (TConstruct i n args) ->
           i = (fst (fst ml)) ->
           tskipn (snd (fst ml)) args = Some args' ->  (* drop parameters *)
           whCaseStep n args' brs = Some cs ->
           WcbvEval p cs s ->
           WcbvEval p (TCase ml mch brs) s
| wCaseCong: forall ml mch emch brs ebrs,
           WcbvEval p mch emch ->
           ~ isConstruct emch ->
           WcbvEvals p brs ebrs ->
           WcbvEval p (TCase ml mch brs) (TCase ml emch ebrs)
| wWrong: WcbvEval p TWrong TWrong
with WcbvEvals (p:environ Term) : Terms -> Terms -> Prop :=
| wNil: WcbvEvals p tnil tnil
| wCons: forall t t' ts ts',
           WcbvEval p t t' -> WcbvEvals p ts ts' -> 
           WcbvEvals p (tcons t ts) (tcons t' ts').
Hint Constructors WcbvEval WcbvEvals.
Scheme WcbvEval1_ind := Induction for WcbvEval Sort Prop
     with WcbvEvals1_ind := Induction for WcbvEvals Sort Prop.
Combined Scheme WcbvEvalEvals_ind from WcbvEval1_ind, WcbvEvals1_ind.

(** when reduction stops **)
Definition no_Wcbv_step (p:environ Term) (t:Term) : Prop :=
  no_step (WcbvEval p) t.
Definition no_Wcbvs_step (p:environ Term) (ts:Terms) : Prop :=
  no_step (WcbvEvals p) ts.

(** evaluate omega = (\x.xx)(\x.xx): nontermination **)
Definition xx := (TLambda nAnon (TApp (TRel 0) (TRel 0))).
Definition xxxx := (TApp xx xx).
Goal WcbvEval nil xxxx xxxx.
unfold xxxx, xx. eapply wAppLam. eapply wLam. eapply wLam.
Abort.

Lemma WcbvEval_weaken:
  forall p,
    (forall t s, WcbvEval p t s -> forall nm ec, fresh nm p ->
                  WcbvEval ((nm,ec)::p) t s) /\
    (forall ts ss, WcbvEvals p ts ss -> forall nm ec, fresh nm p ->
                  WcbvEvals ((nm,ec)::p) ts ss).
Proof.
  intros p. apply WcbvEvalEvals_ind; intros; auto.
  - eapply wConst. 
    + apply Lookup_weaken; eassumption.
    + apply H. assumption.
  - eapply wAppLam.
    + apply H. assumption.
    + apply H0. assumption.
    + apply H1. assumption.
  - eapply wLetIn.
    + apply H. assumption.
    + apply H0. assumption.
  - eapply wAppFix.
    + apply H. assumption.
    + apply e.
    + apply H0. assumption.
  - eapply wCase; intuition; try eassumption.
Qed.


(************  in progress  ****
Lemma WcbvEval_strengthen:
  forall pp,
  (forall t s, WcbvEval pp t s -> forall nm u p, pp = (nm,ecConstr u)::p ->
        ~ PoccTrm nm t -> WcbvEval p t s) /\
  (forall ts ss, WcbvEvals pp ts ss -> forall nm u p, pp = (nm,ecConstr u)::p ->
        ~ PoccTrms nm ts -> WcbvEvals p ts ss).
intros pp. apply WcbvEvalEvals_ind; intros; auto.
- assert (j1:= neq_sym (inverse_Pocc_TConstL H1)).
  assert (j2:= Lookup_strengthen l H0 j1).
  eapply wConst. apply j2. eapply H. eassumption.
  subst.

- eapply wConst.
  assert (j1:= (neq_sym (inverse_Pocc_TConstL H1))). inversion_clear l.
  rewrite H0 in l. assert (j2:= LookupDfn_neq j1 l).
  eapply wConst. eassumption.
  inversion l. eapply H. eassumption.
  + eapply wConst. eassumption.
  eapply wConst. eassumption.
  eapply H. eassumption. intros h.
eapply wConst. subst. eassumption.  (@wConst p nm t s pp).
  eapply (@Lookup_strengthen _ pp); try eassumption.
  + apply (neq_sym (inverse_Pocc_TConstL H1)).
  + eapply H. eassumption.
    admit.
- Check (deMorgan_impl (@PoAppL _ _ _ _) H3).
  assert (hfn:= deMorgan_impl (@PoAppL _ _ _ _) H3).
  assert (harg:= deMorgan_impl (@PoAppA _ _ _ _) H3).
  assert (hargs:= deMorgan_impl (@PoAppR _ _ _ _) H3).
  eapply wAppLam. 
  + eapply H; eassumption.
  + eapply H0; eassumption.
  + eapply H1. eassumption. intros j.

*************)


(** WcbvEval makes progress **)
(******************  HERE  ***
Goal
  forall (p:environ Term),
  (forall t, (no_wnd_step p t /\ (no_Wcbv_step p t \/ WcbvEval p t t)) \/
                 (exists u, wndEvalTC p t u /\ WcbvEval p t u)) /\
  (forall ts, (no_wnds_step p ts /\ WcbvEvals p ts ts) \/
                  (exists us, wndEvalsTC p ts us /\ WcbvEvals p ts us)) /\
  (forall (ds:Defs), True).
induction p; apply TrmTrmsDefs_ind; intros; auto.



Goal
  (forall p n t, Crct p n t -> n = 0 ->
                 (no_wnd_step p t /\ WcbvEval p t t) \/
                 (exists u, wndEvalTC p t u /\ WcbvEval p t u)) /\
  (forall p n ts, Crcts p n ts -> n = 0 ->
                  (no_wnds_step p ts /\ WcbvEvals p ts ts) \/
                  (exists us, wndEvalsTC p ts us /\ WcbvEvals p ts us)) /\
  (forall (p:environ Term) (n:nat) (ds:Defs), CrctDs p n ds -> True).
apply CrctCrctsCrctDs_ind; intros; try auto; subst.
- left. split.
  + intros x h. inversion h.
  + constructor.
- destruct H0; destruct H2; try reflexivity.
  + left. split. intros x h.
    assert (j1:= proj1 H0). assert (j2:= proj1 H2).
    unfold no_wnd_step in j1. eelim j1.
    eapply (proj1 (wndEval_strengthen _)). eapply h. reflexivity.
    eapply (proj1 (Crct_fresh_Pocc)); eassumption.
    apply WcbvEval_weaken; intuition.
  + left. destruct H0. split.
    * unfold no_wnd_step. intros w j. unfold no_wnd_step in H0.
      elim (H0 w). eapply (proj1 (wndEval_strengthen _)).
      eassumption. reflexivity.
      eapply (proj1 Crct_fresh_Pocc); eassumption.
    * eapply (proj1 (WcbvEval_weaken _)); assumption.
  + right. destruct H0. destruct H0. exists x. split.
    * apply wndEvalTC_weaken; assumption.
    * apply WcbvEval_weaken; assumption.
  + right. destruct H0. destruct H0. exists x. split.
    * apply wndEvalTC_weaken; assumption.
    * apply WcbvEval_weaken; assumption.
- omega.
- left. intuition. intros x h. inversion h.
- left. intuition. intros x h. inversion h.
- right. destruct H0; try reflexivity; destruct H0.
  + unfold no_wnd_step in H0. eelim H0.
***)


(** WcbvEval is in the transitive closure of wndEval **)
(**
Lemma WcbvEval_wndEvalTC:
  forall (p:environ Term),
    (forall t s, WcbvEval p t s -> t <> s -> wndEvalTC p t s) /\
    (forall ts ss, WcbvEvals p ts ss -> ts <> ss -> wndEvalsTC p ts ss).
intros p. apply WcbvEvalEvals_ind; intros; try (nreflexivity H).
**)

(************  in progress  ****
Lemma WcbvEval_strengthen:
  forall pp,
  (forall t s, WcbvEval pp t s -> forall nm u p, pp = (nm,ecConstr u)::p ->
        ~ PoccTrm nm t -> WcbvEval p t s) /\
  (forall ts ss, WcbvEvals pp ts ss -> forall nm u p, pp = (nm,ecConstr u)::p ->
        ~ PoccTrms nm ts -> WcbvEvals p ts ss).
intros pp. apply WcbvEvalEvals_ind; intros; auto; subst.
- admit.
- destruct (notPocc_TApp H3) as (hfn & ha1 & hargs). eapply wAppLam.
  + eapply H. reflexivity. assumption.
  + eapply H0. reflexivity. assumption.
  + eapply H1. reflexivity. unfold whBetaStep.


Lemma WcbvEval_strengthen:
  forall pp,
  (forall t s, WcbvEval pp t s -> forall nm u p, pp = (nm,ecConstr u)::p ->
        forall n, Crct pp n t -> ~ PoccTrm nm t -> WcbvEval p t s) /\
  (forall ts ss, WcbvEvals pp ts ss -> forall nm u p, pp = (nm,ecConstr u)::p ->
        forall n, Crcts pp n ts -> ~ PoccTrms nm ts -> WcbvEvals p ts ss).
intros pp. apply WcbvEvalEvals_ind; intros; auto; subst.
- admit.
(***
- eapply wConst. eapply Lookup_strengthen; try eassumption.
  + destruct (string_dec nm nm0); auto.
    * subst. elim H2. constructor. auto.
  + eapply H. eassumption.
    * instantiate (1:= 0). admit. 
(***
subst.  assert (j:= inverse_Pocc_TConstL H2). inversion_Clear l.
      elim j. reflexivity. inversion_Clear H1.

      Check (proj1 (Crct_strengthen) _ _ _ H1). eapply CrctWk. instantiate (1:= 0). admit.
***)
    * subst. assert (j:= inverse_Pocc_TConstL H2). inversion_Clear l.
  
inversion_Clear H1.
***)
- destruct (notPocc_TApp H4); destruct H5. eapply wAppLam. 
   + eapply H; try reflexivity; try eassumption. eapply CrctWk. 

Check (proj1 Crct_strengthen _ _ _ H3). inversion_Clear H3.
  + injection H8. intros. subst. eapply wAppLam. eapply H. reflexivity.
    * eapply Crct_strengthen. 

HERE


(@wConst p nm t s pp). eapply (@Lookup_strengthen _ pp); try eassumption.
  + apply (neq_sym (inverse_Pocc_TConstL H1)).
  + eapply H. eassumption.
    admit.
- Check (deMorgan_impl (@PoAppL _ _ _ _) H3).
  assert (hfn:= deMorgan_impl (@PoAppL _ _ _ _) H3).
  assert (harg:= deMorgan_impl (@PoAppA _ _ _ _) H3).
  assert (hargs:= deMorgan_impl (@PoAppR _ _ _ _) H3).
  eapply wAppLam. 
  + eapply H; eassumption.
  + eapply H0; eassumption.
  + eapply H1. eassumption. intros j.



rewrite H0 in l. assert (j:= proj2 (lookupDfn_LookupDfn _ _ _) l).
  simpl in j.
  rewrite (string_eq_bool_neq (neq_sym (inverse_Pocc_TConstL H1))) in j. 
Check (@wConst p _ t).
  eapply (@wConst p _ t).
assert (h:= inverse_Pocc_TConstL H1).

rewrite H0 in l. simpl in l. eapply (wConst pp). 

rewrite H0 in H. simpl in H.
  rewrite (string_eq_bool_neq (neq_sym (inverse_Pocc_TConstL H0))) in e. 
  trivial.
- apply (H nm u); trivial. apply (notPocc_TApp H1).
- apply (H nm u); trivial. apply (notPocc_TApp H1).
- apply (H nm u); trivial. apply (notPocc_TApp H1).
- apply (H nm0 u); trivial; apply (notPocc_TProd H1).
- apply (H nm0 u); trivial; apply (notPocc_TLambda H1).
- apply (H nm0 u); trivial; apply (notPocc_TLetIn H1).
- apply (H nm0 u); trivial; apply (notPocc_TLetIn H1).
- apply (H nm u); trivial; apply (notPocc_TCast H1).
- apply (H nm u); trivial; apply (notPocc_TCase H1).
- apply (H nm u); trivial; apply (notPocc_TCase H1).
- apply (H nm u); trivial; apply (notPocc_TCase H1).
- apply (H nm u). trivial. apply (notPoccTrms H1).
- apply (H nm u). trivial. apply (notPoccTrms H1).
Qed.
***************)

Section wcbvEval_sec.
Variable p:environ Term.

(** now an executable weak-call-by-value evaluation **)
(** use a timer to make this terminate **)
Function wcbvEval
         (tmr:nat) (t:Term) {struct tmr} : exception Term :=
  match tmr with 
    | 0 => Exc "out of time"          (** out of time  **)
    | S n =>
      match t with      (** look for a redex **)
        | TConst nm =>
          match (lookup nm p) with
            | Some (ecTrm t) => wcbvEval n t
            | Some (ecTyp _ _ _) => raise ("wcbvEval, TConst ecTyp " ++ nm)
            | _ => raise "wcbvEval: TConst environment miss"
          end
        | TConstruct i cn args => 
          match wcbvEvals n args with
            | Ret args' => Ret (TConstruct i cn args')
            | Exc s => raise s
          end
        | TApp fn a1 =>
          match wcbvEval n fn with
            | Ret (TFix dts m) =>
              match whFixStep dts m with
                | None => raise ""
                | Some fs => wcbvEval n (TApp fs a1)
              end
            | Ret Fn =>
              match wcbvEval n a1 with
                | Exc s =>  raise "wcbvEval: TApp, arg doesn't eval"
                | Ret ea1 =>
                  match Fn with
                    | TLambda _ bod => wcbvEval n (whBetaStep bod ea1)
                    | T => Ret (TApp T ea1)
                  end
              end
            | Exc _ => raise "wcbvEval: TApp, fn doesn't eval"
          end
        | TCase ml mch brs =>
          match wcbvEval n mch with
            | Ret (TConstruct i r args) =>
              if eq_dec i (fst (fst ml)) then
                match tskipn (snd (fst ml)) args with
                  | None => raise "wcbvEval: Case, tskipn"
                  | Some ts => match whCaseStep r ts brs with
                                 | None => raise "wcbvEval: Case, whCaseStep"
                                 | Some cs => wcbvEval n cs
                               end
                end
              else raise "wcbvEval: TCase: i doesn't match"
            | Ret emch =>
              match wcbvEvals n brs with
                | Exc s => raise s
                | Ret ebrs => Ret (TCase ml emch ebrs)
              end
            | Exc s => Exc s
          end
        | TLetIn nm df bod =>
          match wcbvEval n df with
            | Exc s => raise s
            | Ret df' => wcbvEval n (instantiate df' 0 bod)
          end
        (** already in whnf ***)
        | TAx => ret TAx
        | TLambda nn t => ret (TLambda nn t)
        | TProd nn t => ret (TProd nn t)
        | TFix mfp br => ret (TFix mfp br)
        | TInd i => ret (TInd i)
        | TSort srt => ret (TSort srt)
        | TProof => ret TProof
        (** should never appear **)
        | TRel _ => raise "wcbvEval: unbound Rel"
        | TWrong => ret TWrong
      end
  end
with wcbvEvals (tmr:nat) (ts:Terms) {struct tmr}
     : exception Terms :=
       (match tmr with 
          | 0 => raise "out of time"         (** out of time  **)
          | S n => match ts with             (** look for a redex **)
                     | tnil => ret tnil
                     | tcons s ss =>
                       match wcbvEval n s, wcbvEvals n ss with
                         | Ret es, Ret ess => Ret (tcons es ess)
                         | _, _ => Exc ""
                       end
                   end
        end).
Functional Scheme wcbvEval_ind' := Induction for wcbvEval Sort Prop
with wcbvEvals_ind' := Induction for wcbvEvals Sort Prop.
Combined Scheme wcbvEvalEvals_ind from wcbvEval_ind', wcbvEvals_ind'.


(** wcbvEval and WcbvEval are the same relation **)
Lemma wcbvEval_WcbvEval:
  forall n,
  (forall t s, wcbvEval n t = Ret s -> WcbvEval p t s) /\
  (forall ts ss, wcbvEvals n ts = Ret ss -> WcbvEvals p ts ss).
Proof.
  intros n.
  apply (wcbvEvalEvals_ind 
           (fun n t (o:exception Term) =>
              forall (s:Term) (p1:o = Ret s), WcbvEval p t s)
           (fun n ts (os:exception Terms) =>
              forall (ss:Terms) (p2:os = Ret ss), WcbvEvals p ts ss));
    intros; try discriminate; try (myInjection p1); try (myInjection p2);
    try(solve[constructor]); intuition.
  - eapply wConst. unfold LookupDfn.
    eapply lookup_Lookup. eassumption. apply H. assumption.
  - specialize (H _ e1). specialize (H0 _ p1).
    eapply wAppFix; try eassumption.
  - specialize (H _ e1). specialize (H0 _ e2). specialize (H1 _ p1).
    eapply wAppLam; try eassumption.
    destruct Fn; try discriminate. myInjection e3. eassumption.
  - specialize (H _ e1). specialize (H0 _ e2).
    destruct T; try contradiction;
    try (myInjection H1); try (apply wAppCong); try assumption;
    try (solve[not_isApp]).
  - subst. specialize (H _ e1). specialize (H0 _ p1). 
    refine (wCase _ _ _ _ _ _ _); eassumption || reflexivity.
  - specialize (H _ e1). specialize (H0 _ e2). 
    eapply wCaseCong; try assumption. 
    destruct emch; try not_isConstruct. contradiction. 
  - eapply wLetIn.
    + apply H. eassumption.
    + apply H0. assumption.
Qed.

(* need this strengthening to large-enough fuel to make the induction
** go through
*)
Lemma WcbvEval_wcbvEval:
    (forall t s, WcbvEval p t s ->
        exists n, forall m, m >= n -> wcbvEval (S m) t = Ret s) /\
    (forall ts ss, WcbvEvals p ts ss ->
        exists n, forall m, m >= n -> wcbvEvals (S m) ts = Ret ss).
Proof.
  assert (j:forall m x, m > x -> m = S (m - 1)). induction m; intuition.
  apply WcbvEvalEvals_ind; intros; try (exists 0; intros mx h; reflexivity).
  - destruct H. exists (S x). intros m h. simpl.
    rewrite (j m x); try omega. rewrite H; try omega. reflexivity.
  - destruct H. exists (S x). intros mx hm. simpl. unfold LookupDfn in l.
    rewrite (Lookup_lookup l). rewrite (j mx 0); try omega. apply H.
    omega.
  - destruct H; destruct H0; destruct H1. exists (S (max x (max x0 x1))).
    intros m h.
    assert (k:wcbvEval m fn = Ret (TLambda nm bod)).
    { rewrite (j m (max x (max x0 x1))). apply H.
      assert (l:= max_fst x (max x0 x1)); omega. omega. }
    assert (k0:wcbvEval m a1 = Ret a1').
    { rewrite (j m (max x (max x0 x1))). apply H0.
      assert (l:= max_snd x (max x0 x1)). assert (l':= max_fst x0 x1).
      omega. omega. }
    simpl. rewrite k0. rewrite k.
    rewrite (j m (max x (max x0 x1))). apply H1. 
    assert (l:= max_snd x (max x0 x1)). assert (l':= max_snd x0 x1).
    omega. omega.
  - destruct H; destruct H0. exists (S (max x x0)). intros m h. simpl.
    assert (k:wcbvEval m dfn = Ret dfn'). 
    assert (l:= max_fst x x0).
    rewrite (j m (max x x0)). apply H. omega. omega.
    rewrite k.
    assert (l:= max_snd x x0).
    rewrite (j m x0). apply H0. omega. omega.
  - destruct H; destruct H0. exists (S (max x x0)). intros mx h.
    assert (l1:= max_fst x x0). assert (l2:= max_snd x x0).
    simpl. rewrite (j mx x); try rewrite (H (mx - 1)); try omega.
    rewrite e. apply H0. omega.
  - destruct H; destruct H0. exists (S (max x x0)). intros mx h.
    assert (l1:= max_fst x x0). assert (l2:= max_snd x x0).
    cbn. rewrite (j mx x); try omega.
    rewrite (H (mx - 1)); try omega.
    rewrite (H0 (mx - 1)); try omega.
    destruct efn; try reflexivity.
    + elim n. auto.
    + elim n0. auto.
  - destruct H as [x hx]. destruct H0 as [x0 hx0].
    exists (S (max x x0)). intros m hm. cbn.
    assert (l1:= max_fst x x0). assert (l2:= max_snd x x0).
    rewrite (j m (max x x0)); try omega.
    rewrite hx; try omega. rewrite e0; try omega. rewrite e1; try omega.
    destruct (inductive_dec i (fst (fst ml))).
    + apply hx0; try omega.
    + elim n0; assumption.
  - destruct H; destruct H0. exists (S (max x x0)). intros m h.
    assert (l:= max_fst x x0). assert (l2:= max_snd x x0). cbn.
    rewrite (j m (max x x0)); try omega. rewrite H; try omega.
    destruct emch; try rewrite H0; try reflexivity; try omega.
    elim n. auto.
  - destruct H; destruct H0. exists (S (max x x0)). intros m h.
    assert (l:= max_fst x x0). assert (l2:= max_snd x x0). cbn.
    rewrite (j m (max x x0)); try omega. rewrite H; try omega.
    rewrite H0. reflexivity. omega.
Qed.

End wcbvEval_sec.


(**** scratch below here ****
(** wcbvEval is monotonic in fuel **)
Goal
  (forall t n p,  wcbvEval n t <> TUnknown"" ->
                   wcbvEval n t = wcbvEval (S n) p t).
induction t; intros. 
- destruct n0; simpl in H; intuition.
- destruct n; simpl in H. intuition. reflexivity.
- destruct n. simpl in H. intuition.  simpl in H. simpl.
  change (TCast (wcbvEval n t1) c t2 = TCast (wcbvEval (S n) p t1) c t2).
  rewrite IHt1. reflexivity. intros h. rewrite <- h in H.

unfold wcbvEval in H. simpl.


         (forall (t s:Term), wcbvEval p t s ->
             exists n, s = wcbvEval n t) /\
         (forall ts ss, WcbvEvals p ts ss ->
             exists n, ss = tmap (wcbvEval n p) ts).
Goal
  forall (p:environ Term),
         (forall (t s:Term), wcbvEval p t s ->
             exists n, s = wcbvEval n t) /\
         (forall ts ss, WcbvEvals p ts ss ->
             exists n, ss = tmap (wcbvEval n p) ts).

(** WcbvEval and wcbvEval are the same relation **)
Goal
  forall (p:environ Term),
         (forall (t s:Term), WcbvEval p t s ->
             exists n, s = wcbvEval n t) /\
         (forall ts ss, WcbvEvals p ts ss ->
             exists n, ss = tmap (wcbvEval n p) ts).
intros p.
apply WcbvEvalEvals_ind; intros; try (exists 1; reflexivity).
- destruct H. exists (S x). subst.
  assert (j:= proj2 (lookupDfn_LookupDfn _ _ _) l).
  simpl. rewrite j. reflexivity.
- destruct H. destruct H0. destruct H1.
  exists (S (x + x0 + x1)). subst. unfold whBetaStep. simpl.






Qed.

(** use a timer to make this Terminate **)
Fixpoint wcbvEval (tmr:nat) (p:environ Term) (t:Term) {struct tmr} : nat * Term :=
  match tmr with 
    | 0 => (0, TUnknown "time")          (** out of time  **)
    | S n => match t with  (** look for a redex **)
               | TConst nm => match (lookupDfn nm p) with
                                | Some t => wcbvEval n t
                                | None =>  (0, TUnknown nm)
                              end
               | TApp fn a1 args =>
                 let (_,efn) := wcbvEval n fn in
                 match efn with
                   | TLambda _ _ bod =>
                     let (_,wharg) := wcbvEval n a1 in
                     wcbvEval n (whBetaStep bod wharg args)
                   | TFix dts m =>
                     wcbvEval n (whFixStep dts m (tcons a1 args))
                   | TConstruct _ r =>
                     let (_,ea1) := wcbvEval n a1 in
                     let eargs := 
                         tmap (fun t =>
                                 let (_,et) := wcbvEval n t in et) args in
                     (n, TApp efn ea1 eargs)
                   | _ => (n, TUnknown"App")
                 end
               | TCase np _ mch brs =>
                 let (_,emch) := wcbvEval n mch in
                 match emch with 
                   | TConstruct _ r => wcbvEval n (whCaseStep r tnil brs)
                   | TApp (TConstruct _ r) arg args =>
                     wcbvEval n p
                              (whCaseStep r (tskipn np (tcons arg args)) brs)
                   | _ => (n, TUnknown"Case")
                 end
               | TLetIn nm df ty bod =>
                 let (_,df') := wcbvEval n df in
                 wcbvEval n (instantiate df' 0 bod)
               | TCast t1 ck t2 => (n, TCast (snd (wcbvEval n t1)) ck t2)
               (** already in whnf ***)
               | TLambda nn ty t => (n, TLambda nn ty t)
               | TProd nn ty t => (n, TProd nn ty t)
               | TFix mfp br => (n, TFix mfp br)
               | TConstruct i cn => (n, TConstruct i cn)
               | TInd i => (n, TInd i)
               | TSort srt => (n, TSort srt)
               (** should never appear **)
               | TRel _ => (0, TUnknown "TRel")
               | TUnknown s => (0, TUnknown s)
             end
  end.

(** If wcbvEval has fuel left, then it has reached a weak normal form **)
(**
Goal
  forall (p:environ Term) t s n m, (wcbvEval n t) = (S m, s) -> WNorm s.
***)

(** WcbvEval and wcbvEval are the same relation **)
Goal
  forall (p:environ Term),
         (forall (t s:Term), WcbvEval p t s ->
             exists n, s = snd (wcbvEval n t)) /\
         (forall ts ss, WcbvEvals p ts ss ->
        exists n, ss = tmap (fun t => let (_,et) := wcbvEval n t in et) ts).
intros p.
apply WcbvEvalEvals_ind; intros; try (exists 1; reflexivity).
- destruct H. exists (S x). subst.
  assert (j:= proj2 (lookupDfn_LookupDfn _ _ _) l).
  simpl. rewrite j. reflexivity.
- destruct H. destruct H0. destruct H1.
  exists (S (x + x0 + x1)). simpl.




(***** scratch below here ****************


Goal forall (p:environ Term) t s, WcbvEval p t s -> crct p t -> wNorm s = true.
induction 1; destruct 1. 
- apply IHWcbvEval. split. assumption. unfold weaklyClosed. intros nmx j.
  unfold weaklyClosed in H2. apply H2. inversion H1. subst.
  + specialize (H2 nm). unfold poccTrm in H2; simpl in H2.
    rewrite string_eq_bool_rfl in H2. intuition.
  + apply sBeta.



HERE

  + destruct (string_dec nmx nm).
    * subst. unfold poccTrm. rewrite string_eq_bool_rfl. reflexivity.
    * inversion H1. subst. inversion_clear H0. inversion H.
  
    simpl in H3.

  + unfold poccTrm. inversion H1. subst. inversion h. unfold weaklyClosed in H3.
    simpl in H3.




Goal forall (p:environ Term), 
  (forall t s, WcbvEval p t s -> crct p t -> wNorm s = true) /\
  (forall ts ss, WcbvEvals p ts ss ->
        Forall (crct p) ts -> Forall (fun s => wNorm s = true) ss).
intros p.
apply WcbvEvalEvals_ind.
- intros nm t s q h1 h2 h3 h4. apply h3. inversion h2; subst.
  + split.
    * inversion h4. auto.
    * unfold  weaklyClosed. intros nm1 j1.
      simpl in j1. assert (j2:= string_eq_bool_eq _ _ j1). subst.
      assert (j3:= proj2 (lookupDFN_LookupDFN _ _ _) H).
      unfold lookupDfn. rewrite j3. intros j4. discriminate.
  + destruct h4. split. auto. unfold weaklyClosed.
    intros nm1 h4. simpl in h4.

induction 1; inversion 1.
- subst. elim (ncrct_nil_TConst nm _ _ H1); reflexivity.
- subst. apply IHWcbvEval.

HERE




(***
Lemma instantiate_arg_resp_WcbvEval:
  (forall p ia2 s, WcbvEval p ia2 s -> 
    forall a1 a2 bod, ia2 = (instantiate 0 bod a2) -> 
    WcbvEval p a1 a2 -> WcbvEval p (instantiate 0 bod a1) s) /\
  (forall p ia2 s, WcbvEvals p ia2s ss -> 
    forall a1 a2 bod, ia2 = (instantiate 0 bod a2) -> 
    WcbvEval p a1 a2 -> WcbvEval p (instantiate 0 bod a1) s)
induction 1. intros ax a2 bod heq h.
- eapply IHWcbvEval. intuition. assumption.
- eapply IHWcbvEval3. assumption.
- eapply IHWcbvEval2. assumption.
- eapply 
***)

Lemma nat_compare_Gt: forall n, nat_compare (S n) n = Gt.
induction n; intuition.
Qed.
Lemma nat_compare_Lt: forall n, nat_compare n (S n) = Lt.
induction n; intuition.
Qed.
Lemma nat_compare_Eq: forall n, nat_compare n n = Eq.
induction n; intuition.
Qed.

Lemma instantiate_is_Const:
  forall m bod a nm, instantiate m bod a = TConst nm ->
                        a = TConst nm \/ bod = TConst nm.
induction bod; intros a nm h; simpl in h; try discriminate h.
- case_eq (nat_compare m n); intro j; rewrite j in h;
  try assumption; try discriminate h. intuition.
- intuition.
Qed.

(**
Goal
  forall p ia2 s, WcbvEval p ia2 s -> 
     forall bod a1 a2, ia2 = (instantiate 0 bod a2) -> WcbvEval p a1 a2 ->
                    WcbvEval p (instantiate 0 bod a1) s.
induction 1; intros bodx ax a2 heq h.
- symmetry in heq. case (instantiate_is_Const _ _ _ _ heq); intro j.

Lemma WcbvEval_unique:
  forall (p:environ Term) (t s1:Term),
    WcbvEval p t s1 -> forall (s2:Term), WcbvEval p t s2 -> s1 = s2.
induction 1.
- inversion_clear 1. eapply IHWcbvEval.
  assert (j: t = t0). rewrite H in H2; injection H2; intuition.
  rewrite j; assumption.
- inversion_clear 1.
  + eapply IHWcbvEval3. unfold whBetaStep. unfold whBetaStep in H5.
    injection (IHWcbvEval1 _ H3); intros; subst.
***)



(**
Ltac Tran_step := eapply Relation_Operators.rt1n_trans.

Ltac const_step :=
  tran_step; [eapply sConst; unfold lookupDfn, lookupDFN; simpl; reflexivity|].
**)
(***
Goal
  forall p fn nm ty bod a1 a1' s args,
    clos_trans_n1 Term (wndEval p) fn (TLambda nm ty bod) ->
    clos_trans_n1 Term (wndEval p) a1 a1' ->
    clos_trans_n1 Term (wndEval p) (whBetaStep nm bod a1' args) s ->
    clos_trans_n1 Term (wndEval p) (TApp fn (a1 :: args)) s.
intros p fn nm ty bod a1 a1' s args hfn ha1 hstep.
inversion hfn; inversion ha1; inversion hstep.
- tran_step. eassumption.
  tran_step. eapply sAppArgs. eapply saHd. eassumption.    
  tran_step. eapply sBeta. eassumption.
- tran_step. eapply sAppFun. eassumption.
  tran_step. eapply sAppArgs. eapply saHd. eassumption.
  tran_step. eapply sBeta. eassumption.
- tran_step. eapply sAppFun. eassumption.
  tran_step. eapply sAppArgs. eapply saHd. eapply tn1_step. eassumption.
  tran_step. eapply sBeta. eassumption.
***)


(**
Goal
  forall p a a',
    clos_refl_trans Term (wndEval p) a a' ->
    forall bod args,
      clos_refl_trans Term (wndEval p) (mkApp (instantiate 0 bod a) args)
                         (mkApp (instantiate 0 bod a') args).
intros p a a' h bod. induction h; intro args.
- apply rt_step.
 Check  Relation_Operators.rt1n_trans.



Goal
  forall p fn nm ty bod a1 a1' s args,
    clos_refl_trans_1n Term (wndEval p) fn (TLambda nm ty bod) ->
    clos_refl_trans_1n Term (wndEval p) a1 a1' ->
    clos_refl_trans_1n Term (wndEval p) (whBetaStep nm bod a1' args) s ->
    clos_refl_trans_1n Term (wndEval p) (TApp fn (a1 :: args)) s.
intros p fn nm ty bod a1 a1' s args hfn ha1 hstep.
inversion hfn; inversion ha1; inversion hstep.
- tran_step. subst. eapply sBeta. subst. auto. 
- tran_step. subst. eapply sBeta. subst. eassumption.
- assert (j: clos_refl_trans_1n Term (wndEval p) a1 a1').
  tran_step; eassumption.
  tran_step. eapply sBeta. rewrite H3. destruct nm.
  + simpl. simpl in H3. rewrite H3. eapply rt1n_refl.
  + simpl. simpl in H3. rewrite <- H3.
-


 tran_step. eapply sAppArgs. eapply saHd. eassumption.
  tran_step.

  eapply (t1n_trans _ (wndEval p)). eapply t1n_step. eapply sAppArgs. eapply saHd.
  eapply clos_t1n_trans. 

eapply (t1n_trans _ (wndEval p)).


 Check (t1n_trans _ _ _ H1).
  tran_step. eapply sAppArgs. eapply saHd. eassumption.
  tran_step. eapply sBeta. eassumption.
- tran_step. eapply sAppFun. eassumption.


Goal
  forall p fn nm ty bod a1 a1' s args,
    clos_trans_1n Term (wndEval p) fn (TLambda nm ty bod) ->
    clos_trans_1n Term (wndEval p) a1 a1' ->
    clos_trans_1n Term (wndEval p) (whBetaStep nm bod a1' args) s ->
    clos_trans_1n Term (wndEval p) (TApp fn (a1 :: args)) s.
intros p fn nm ty bod a1 a1' s args hfn ha1 hstep.
inversion hfn; inversion ha1; inversion hstep.
- tran_step. eapply sAppFun. eassumption.
  tran_step. eapply sAppArgs. eapply saHd. eassumption.    
  tran_step. eapply sBeta. eassumption.
- tran_step. eapply sAppFun. eassumption.
  tran_step. eapply sAppArgs. eapply saHd. eassumption.
  tran_step. eapply sBeta. eassumption.
- tran_step. eapply sAppFun. eassumption.

  tran_step. eapply sAppArgs. eapply saHd. eassumption.
  tran_step. eapply sBeta. eassumption.


Goal
  forall p fn nm ty bod a1 a1' s args,
    clos_trans Term (wndEval p) fn (TLambda nm ty bod) ->
    clos_trans Term (wndEval p) a1 a1' ->
    clos_trans Term (wndEval p) (whBetaStep nm bod a1' args) s ->
    clos_trans Term (wndEval p) (TApp fn (a1 :: args)) s.
intros p fn nm ty bod a1 a1' s args hfn ha1 hstep.
inversion hfn; inversion ha1; inversion hstep.
- tran_step. eapply sAppFun. eassumption.
  tran_step. eapply sAppArgs. eapply saHd. eassumption.    
  tran_step. eapply sBeta.
  eassumption.
unfold whBetaStep in H3.
***)

(**
Ltac Tran_step := eapply Relation_Operators.rt1n_trans.

Goal forall p t t', WcbvEval p t t' -> clos_refl_trans_1n _ (wndEval p) t t'.
induction 1.
- Tran_step. eapply sConst. rewrite H. reflexivity. assumption.
- tran_step. eapply sAppFun.
Check (rt_refl Term (wndEval p)). _ (wndEval p) _ IHWcbvEval1).
**)

Definition Nat := nat.
Definition typedef := ((fun (A:Type) (a:A) => a) Nat 1).
Quote Definition q_typedef := Eval compute in typedef.
Quote Recursively Definition p_typedef := typedef.
Definition P_typedef := program_Program p_typedef nil.
Definition Q_typedef := 
  Eval compute in (wcbvEval 100 (env P_typedef) (main P_typedef)).
Goal snd Q_typedef = q_typedef.
reflexivity.
Qed.


Definition II := fun (A:Type) (a:A) => a.
Quote Definition q_II := Eval compute in II.
Quote Recursively Definition p_II := II.
Definition P_II := program_Program p_II nil.
Definition Q_II :=
  Eval compute in (wcbvEval 4 (env P_II)) (main P_II).
Goal snd Q_II = q_II.
reflexivity.
Qed.

(***
Eval cbv in (wcbvEval 4 p_II) (main p_II).
Quote Recursively Definition II_nat_pgm := (II nat).
Print II_nat_pgm.
Eval compute in (wcbvEval 4 II_nat_pgm) (main II_nat_pgm).


Quote Definition II_2_Term := (II nat 2).
Print II_2_Term.
Eval compute in II_2_Term.
Quote Recursively Definition II_2_program := (II nat 2).
Print II_2_program.
Quote Definition two_Term := 2.

Eval cbv in (wcbvEval 4 II_2_program) (main II_2_program).

Quote Recursively Definition p_plus22 := (plus 2 2).
Print p_plus22.
Quote Definition q_ans := 4.
Eval cbv in (wcbvEval 20 p_plus22) (main p_plus22).

Eval compute in (plus 1 2).
Quote Recursively Definition p_plus12 := (plus 1 2).
Eval cbv in (wcbvEval 99 p_plus12) (main p_plus12).

Quote Recursively Definition p_anon := ((fun (_:nat) => 1 + 3) (3 * 3)).
Eval cbv in (wcbvEval 20 p_anon) (main p_anon).

Fixpoint even (n:nat) : bool :=
  match n with
    | 0 => true
    | (S n) => odd n
  end
with
odd (n:nat) : bool :=
  match n with
    | 0 => false
    | (S n) => even n
  end.

Quote Recursively Definition p_even99 := (even 99).
Time Eval cbv in (wcbvEval 500 p_even99) (main p_even99).
Quote Recursively Definition p_odd99 := (odd 99).
Time Eval cbv in (wcbvEval 500 p_odd99) (main p_odd99).


Fixpoint slowFib (n:nat) : nat :=
  match n with
    | 0 => 0
    | S m => match m with
               | 0 => 1
               | S p => slowFib p + slowFib m
             end
  end.
Eval compute in (slowFib 0).
Eval compute in (slowFib 1).
Eval compute in (slowFib 2).
Eval compute in (slowFib 3).
Eval compute in (slowFib 4).
Quote Recursively Definition p_slowFib1 := (slowFib 1).
Quote Recursively Definition p_slowFib2 := (slowFib 2).
Quote Recursively Definition p_slowFib3 := (slowFib 3).
Quote Recursively Definition p_slowFib4 := (slowFib 4).
Quote Recursively Definition p_slowFib5 := (slowFib 5).
Quote Recursively Definition p_slowFib6 := (slowFib 6).
Quote Recursively Definition p_slowFib7 := (slowFib 7).
Quote Recursively Definition p_slowFib10 := (slowFib 10).
Quote Recursively Definition p_slowFib15 := (slowFib 15).
Eval cbv in (wcbvEval 99 p_slowFib3) (main p_slowFib3).
Eval cbv in (wcbvEval 99 p_slowFib4) (main p_slowFib4).
Eval cbv in (wcbvEval 99 p_slowFib5) (main p_slowFib5).
Eval cbv in (wcbvEval 99 p_slowFib6) (main p_slowFib6).
Time Eval cbv in (wcbvEval 99 p_slowFib7) (main p_slowFib7).
Time Eval cbv in (wcbvEval 99 p_slowFib10) (main p_slowFib10).
Time Eval cbv in (wcbvEval 200 p_slowFib15) (main p_slowFib15).


Fixpoint fibrec (n:nat) (fs:nat * nat) {struct n} : nat :=
  match n with
    | 0 => fst fs
    | (S n) => fibrec n (pair ((fst fs) + (snd fs)) (fst fs))
  end.
Definition fib : nat -> nat := fun n => fibrec n (pair 0 1).

Eval compute in (fib 0).
Eval compute in (fib 1).
Eval compute in (fib 2).
Eval compute in (fib 3).
Eval compute in (fib 4).
Eval compute in (fib 6).
Quote Recursively Definition p_fib1 := (fib 1).
Quote Recursively Definition p_fib2 := (fib 2).
Quote Recursively Definition p_fib3 := (fib 3).
Quote Recursively Definition p_fib4 := (fib 4).
Quote Recursively Definition p_fib5 := (fib 5).
Quote Recursively Definition p_fib6 := (fib 6).
Quote Recursively Definition p_fib7 := (fib 7).
Quote Recursively Definition p_fib10 := (fib 10).
Quote Recursively Definition p_fib15 := (fib 15).
Eval cbv in (wcbvEval 20 p_fib1) (main p_fib1).
Eval cbv in (wcbvEval 30 p_fib2) (main p_fib2).
Eval cbv in (wcbvEval 40 p_fib3) (main p_fib3).
Eval cbv in (wcbvEval 50 p_fib4) (main p_fib4).
Eval cbv in (wcbvEval 60 p_fib5) (main p_fib5).
Eval cbv in (wcbvEval 60 p_fib6) (main p_fib6).
Time Eval cbv in (wcbvEval 70 p_fib7) (main p_fib7).
Time Eval cbv in (wcbvEval 70 p_fib10) (main p_fib10).
Time Eval cbv in (wcbvEval 200 p_fib15) (main p_fib15).


Quote Recursively Definition l_fib4 := (let x := 4 in fib x).
Eval cbv in (wcbvEval 50 l_fib4) (main l_fib4).

Fixpoint evenP (n:nat) {struct n} : bool :=
  match n with
    | 0 => true
    | S p => (oddP p)
  end
with oddP (n:nat) : bool :=
  match n with
    | 0 => false
    | S p => evenP p
  end.

Quote Recursively Definition p_evenOdd := (even 100).
Quote Recursively Definition f_evenOdd := (odd 100).
Eval cbv in (wcbvEval 500 p_evenOdd) (main p_evenOdd).
Eval cbv in (wcbvEval 500 f_evenOdd) (main f_evenOdd).

Quote Recursively Definition l_evenOdd := (even (let x := 50 in 2 * x)).
Time Eval cbv in (wcbvEval 500 l_evenOdd) (main l_evenOdd).
Time Eval cbv in (wcbvEval 5000 l_evenOdd) (main l_evenOdd).

Parameter axiom:nat.
Quote Recursively Definition p_axiom := (let x := axiom in 2 * x).
Print p_axiom.
Time Eval cbv in (wcbvEval 100 p_axiom) (main p_axiom).
Time Eval cbv in (wcbvEval 200 p_axiom) (main p_axiom).

***********)

(***
Goal forall p s t,
       WcbvEval p s t -> exists (n m:nat), wcbvEval n s  = (S m, t).
induction 1.
- destruct IHWcbvEval. destruct H1. exists (S x). exists x0.
  simpl. rewrite H. assumption.
- destruct IHWcbvEval1, IHWcbvEval2, IHWcbvEval3.
  destruct H2, H3, H4.
  exists (S (x + x0 + x1)). exists (S (x2 + x3 + x4)).
  simpl.
***)

(* Coq doesn't evaluate the type of a cast *)
Eval cbv in  3 : ((fun n:Type => nat) Prop).
Eval lazy in  3 : ((fun n:Type => nat) Prop).
Eval hnf in  3 : ((fun n:Type => nat) Prop).
Eval vm_compute in  3 : ((fun n:Type => nat) Prop).

Goal 
  forall (t s:Term) (n m:nat) (e:environ Term),
  wcbvEval (S n) e t = (S m,s) -> wNorm s = true.
intros t; induction t; intros; try discriminate;
try (injection H; intros h1 h2; rewrite <- h1; auto; subst).
- simpl. simpl in H. rewrite h2 in H. rewrite h1. erewrite IHt1.


Lemma not_ltb_n_0: forall (n:nat), ltb n 0 = false.
induction n; unfold ltb; reflexivity.
Qed.

Lemma wcbvEval_up:
  forall (n:nat) (p:program) (s:Term),
   closedTerm 0 s = true -> fst (wcbvEval n s) > 0 ->
   snd (wcbvEval n s) = snd (wcbvEval (S n) p s).
intros n p s h1. induction n. simpl. omega.
intros h2.
induction s; simpl in h1; try rewrite not_ltb_n_0 in h1;
try discriminate; try reflexivity.
Admitted.

(***
intros n p s h. induction n. simpl. intro h1. omega.
intro h1. induction s; try reflexivity.
- rewrite IHs2.
***)

Goal forall (strt:nat) (p:program) (s:Term),
       wNorm s = true -> snd (wcbvEval strt p s) = s.
intros strt p s h. induction strt. reflexivity.
induction s; simpl in h; try discriminate h; try reflexivity.
- rewrite <- IHstrt. rewrite -> IHstrt at 1. rewrite <- wcbvEval_up. reflexivity. simpl.

- rewrite <- IHstrt. rewrite -> IHstrt at 1. admit.
- rewrite <- IHstrt. rewrite -> IHstrt at 1. admit.
- rewrite <- IHstrt. rewrite -> IHstrt at 1. admit.
- rewrite <- IHstrt. rewrite -> IHstrt at 1. admit.
Qed.

Goal forall (strt:nat) (p:program) (s:Term),
       fst (wcbvEval strt p s) > 0 -> wNorm (snd (wcbvEval strt p s)) = true.
intros strt p s h. induction s; unfold wcbvEval; simpl.

*******************)
*****)
