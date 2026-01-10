using System.Collections.Generic;
using UdonSharp.Compiler.Assembly;
using UdonSharp.Compiler.Assembly.Instructions;

namespace UdonSharpOptimizer.Optimizations
{
    internal class OPTUnreadCopy : BaseOptimization
    {
        protected override string GUILabel => "Unread Copy";

        public override bool Enabled => OptimizerSettings.Instance.CleanUnreadCopy;

        public override void ProcessInstruction(Optimizer optimizer, List<AssemblyInstruction> instrs, int i)
        {
            // Remove Copy: Unread target (Cleans up Cow dirty)
            if (instrs[i] is CopyInstruction cInst)
            {
                if (Optimizer.IsPrivate(cInst.TargetValue) && !optimizer.ReadScan(_ => false, cInst.TargetValue))
                {
                    instrs[i] = optimizer.TransferInstr(Optimizer.CopyComment("OPTUnreadCopy", cInst), cInst);
                    CountRemoved(optimizer, 3); // PUSH, PUSH, COPY
                }
            }
        }
    }
}
